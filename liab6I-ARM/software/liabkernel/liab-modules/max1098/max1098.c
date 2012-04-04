#include <linux/module.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/mutex.h>
#include <linux/jiffies.h>
#include <linux/timer.h>
#include <linux/spi/spi.h>
#include <linux/interrupt.h>
#include <linux/cdev.h>
#include <linux/ioctl.h>
#include <linux/fs.h>
#include <linux/poll.h>

#include <linux/gpio.h>
#include <asm/gpio.h>
#include <mach/at91rm9200.h>

#define DEBUG(...) \
  printk("max1098 - "__VA_ARGS__)

#define MAX1098_CONF_START 0x8000
#define MAX1098_CONF_PM_NORMAL  0x0600
#define MAX1098_CONF_REF   0x0100

#define MAX1098_CONV_START 0x00a0

#define NO_CHANNELS 4
extern struct file_operations max1098_fops;


/* struct max1098_channel{ */
/*     unsigned short cmd; */
/* }; */

struct spi_max1098 {
    u8 channel;
    char			name[24]; 
    struct spi_message	spi_msg;
    struct spi_transfer	xfer;
    u8 spi_txbuf[40];
    u8 spi_rxbuf[40];
    struct timer_list check_timer;
	struct spi_device	*spi;
    wait_queue_head_t   spi_queue;
    wait_queue_head_t   samp_queue;
    struct cdev  dev;
    int spi_complete;
    int samp_complete;
    struct semaphore sem;

    unsigned short cmd[NO_CHANNELS];
};

static void spi_complete(void *data)
{
    struct spi_max1098 *priv = (struct spi_max1098 *)data;
    
    priv->spi_complete = 1;
    wake_up_interruptible(&priv->spi_queue);
    
}


irqreturn_t sstrb_interrupt(int irq, void *data)
{
    struct spi_max1098 *priv = (struct spi_max1098 *)data; 

    if( at91_get_gpio_value(AT91_PIN_PD18)){
        priv->samp_complete = 1;
        wake_up_interruptible(&priv->samp_queue);
    }

    return IRQ_HANDLED;
}

static int max1098_spi_trcve(struct spi_max1098 *priv, unsigned short cmd, unsigned short *ret)
{

    priv->spi_txbuf[0] = (cmd&0xff00)>>8; /* setup */
    priv->spi_txbuf[1] = (cmd&0x00ff);     /* channel */
    
    priv->spi_complete = 0;
    spi_async(priv->spi, &priv->spi_msg);

    if( wait_event_interruptible(priv->spi_queue, priv->spi_complete)){
        printk("spi wait interrupted\n");
        return -ERESTARTSYS;
    }

    *ret = (priv->spi_rxbuf[0] << 8) | (priv->spi_rxbuf[1] );

    return 0;

}

static short max1098_read_ad(struct spi_max1098 *priv, int channel){
    
    unsigned short ret =0;
    int retval;
    
    if(down_interruptible(&priv->sem)){
        printk("semaphore wait interrupted\n");
        return -ERESTARTSYS;
    }

    priv->samp_complete = 0;

    retval =  max1098_spi_trcve(priv, priv->cmd[channel] , &ret);
    if(retval < 0){
        ret = retval;
        goto out;
    }

    if( wait_event_interruptible(priv->samp_queue, priv->samp_complete)){
        printk("samp wait interrupted\n");
        ret = -ERESTARTSYS;
        goto out;        
    }

    retval =  max1098_spi_trcve(priv, 0, &ret);

    if(retval < 0){
        ret = retval;
        goto out;
    }

  out:
    up(&priv->sem);

    return ret;

}

static void do_spi(unsigned long data)
{
  struct spi_max1098 *priv = (struct spi_max1098 *)data;  
  max1098_read_ad(priv, 0);
  
  mod_timer(&priv->check_timer, jiffies + 100);
}


static int max1098_open(struct inode *inode, struct file *filp)
{

    filp->private_data = (void*)inode;

 	if (!try_module_get(max1098_fops.owner))  
  		return -ENODEV;  
    
    return 0;
}

static int max1098_release(struct inode *inode, struct file *filep)
{
    module_put(max1098_fops.owner); 
    return 0;
}



static int max1098_ioctl(struct inode *inode, struct file *file,
                    unsigned int cmd, unsigned long arg)
{
    int retval = 0;


    printk(KERN_INFO "max1098 module ioctl: %d, %lx\n", cmd, arg);

    return retval;
}


static struct spi_max1098 *priv = NULL;


static ssize_t max1098_write(struct file *filp, const char *ubuf, 
                               size_t count, loff_t *offp)
{
    return count;
}



static ssize_t max1098_read(struct file *filp, char *ubuf, 
                              size_t count, loff_t *offp)
{
    struct inode *inode = (struct inode *)filp->private_data;
    int channel = iminor(inode);
    int ret = 0;
    char ascii[32];
    
    if(channel < 0 || channel > NO_CHANNELS)
        return -EFAULT;

    ret = max1098_read_ad(priv, channel);

    sprintf(ascii, "%d\n", ret);

    if(copy_to_user(ubuf, ascii , strlen(ascii))){
        return -EFAULT;
    }

    return  strlen(ascii);

}


static unsigned int max1098_poll(struct file *filep, 
                                 struct poll_table_struct *wait)
{

	ulong mask = 0;
    
    printk(KERN_INFO "max1098 poll\n");

    return mask;
}



struct file_operations max1098_fops =
{
	.owner   = THIS_MODULE,
    .open    = max1098_open,
    .release = max1098_release,
    .write   = max1098_write,
    .read    = max1098_read,
    .ioctl   = max1098_ioctl,
    .poll    = max1098_poll,
};

#define MAX1098_MAJOR 63
#define MAX1098_MINOR 0

static int __devinit max1098_probe(struct spi_device *spi)
{
    int status = 0;
    int i = 0;
    int err;
    dev_t devno;
    
	DEBUG("%s - probing for MAX1098 A/D converter\n", spi->dev.bus_id);

	priv = kzalloc(sizeof *priv, GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

    init_MUTEX(&priv->sem);

    init_waitqueue_head(&priv->samp_queue);
    init_waitqueue_head(&priv->spi_queue);
    
   	cdev_init(&priv->dev, &max1098_fops);
	priv->dev.owner = THIS_MODULE;
	priv->dev.ops   = &max1098_fops;

    devno = MKDEV(MAX1098_MAJOR, MAX1098_MINOR);
    
    printk (KERN_INFO "dev number %d %d\n", MAJOR(devno), MINOR(devno));
    
	err = cdev_add(&priv->dev, devno, NO_CHANNELS);
	if (err)
    {
		printk (KERN_NOTICE "Error %d adding mydots device\n", err);
        return err;
    }

    for(i = 0; i < NO_CHANNELS; i++)    
        priv->cmd[i] = MAX1098_CONF_START | MAX1098_CONF_PM_NORMAL | MAX1098_CONF_REF | MAX1098_CONV_START | i;


	priv->spi = spi;
  
	/* name must be usable with cmdlinepart */
	sprintf(priv->name, "spi%d.%d-%s",
          spi->master->bus_num, spi->chip_select,
          "max1098");

  /* Assign the priv data */
    dev_set_drvdata(&spi->dev, priv);
    
    /* Enable power for the analog inputs */
//  at91_set_gpio_output(AT91_PIN_PD14, 1);
    gpio_direction_output(AT91_PIN_PD14, 1);
    /* Set the strobe pin to input */
    at91_set_gpio_input(AT91_PIN_PD18, 0);
//  gpio_direction_input(AT91_PIN_PD18, 0);
    at91_set_deglitch(AT91_PIN_PD18, 1);
 
    
    printk (KERN_INFO "interrupt requested\n");

  /* Setup spi */
	spi->bits_per_word = 8;
	spi->mode = SPI_MODE_0;
  //spi->max_speed_hz = 1000 * 1000;
	spi_setup(spi);

    /* Set up the spi message struct */
    spi_message_init(&priv->spi_msg);
	priv->spi_msg.complete = spi_complete;
	priv->spi_msg.context  = priv;
    priv->channel = 0;
    i= 0;

    memset(&priv->spi_txbuf, 0xff, sizeof(priv->spi_txbuf));
    memset(&priv->spi_rxbuf, 0xff, sizeof(priv->spi_rxbuf));
    
    /* Command */
    priv->xfer.tx_buf = &priv->spi_txbuf;
    priv->xfer.rx_buf = &priv->spi_rxbuf;
    priv->xfer.len = 2;

    spi_message_add_tail(&priv->xfer, &priv->spi_msg);

    
    /* Add timer */  
    init_timer(&priv->check_timer);
    priv->check_timer.data = (unsigned long)priv;
    priv->check_timer.function = do_spi;
    priv->check_timer.expires = jiffies + 10;
    // add_timer(&priv->check_timer);
    
    if (request_irq(gpio_to_irq(AT91_PIN_PD18), sstrb_interrupt, 0, "adcstrb", (void*)priv)) {
        printk("IRQ busy\n");
        return -EBUSY;

    }

    DEBUG("priv %p \n", priv);

  
  return status;
}

static int __devexit max1098_remove(struct spi_device *spi)
{
	struct spi_max1098 *priv = dev_get_drvdata(&spi->dev);
	int	status = 0;

    DEBUG("priv %p\n", priv);

    disable_irq(gpio_to_irq(AT91_PIN_PD18));
    gpio_free(AT91_PIN_PD18);
	DEBUG("%s - remove\n", spi->dev.bus_id);
  del_timer(&priv->check_timer);

  free_irq(gpio_to_irq(AT91_PIN_PD18), (void*)priv);

  /* Disable power for the analog inputs */
  at91_set_gpio_input(AT91_PIN_PD14, 0);

  cdev_del(&priv->dev);

  kfree(priv);
	return status;
}

static struct spi_driver max1098_driver = {
	.driver = {
		.name		= "max1098",
		.bus		= &spi_bus_type,
		.owner		= THIS_MODULE,
	},

	.probe		= max1098_probe,
	.remove		= __devexit_p(max1098_remove),

	/* FIXME:  investigate suspend and resume... */
};

static int __init max1098_init(void)
{
	return spi_register_driver(&max1098_driver);
}
module_init(max1098_init);

static void __exit max1098_exit(void)
{
	spi_unregister_driver(&max1098_driver);
}
module_exit(max1098_exit);

MODULE_DESCRIPTION("MAX1098 A/D module");
MODULE_AUTHOR("LIAB ApS. <http://www.liab.dk>");
MODULE_LICENSE("GPL");
