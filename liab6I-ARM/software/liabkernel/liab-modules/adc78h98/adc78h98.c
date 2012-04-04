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

#define MAX1098_CONF_START 0x8000
#define MAX1098_CONF_PM_NORMAL  0x0600
#define MAX1098_CONF_REF   0x0100
#define MAX1098_CONV_START 0x00a0


//#define ADC_ACD78H98
#ifndef ADC_MAX1098
/* adc78h98 */
//#define ADC_SSTRB_PIN 
#define ADC_NAME   "adc78h98"
#define NO_CHANNELS 8
//#define ADC_POWER_PIN  AT91_PIN_PB18
#define ADC_CHACONF (channel << (3+8))
#define ADCXMOD_MAJOR 63
#define ADCXMOD_MINOR 0
#else
/* max1098 */
#define ADC_NAME   "max1098"
#define NO_CHANNELS 4
#define ADC_SSTRB_PIN  AT91_PIN_PD18
#define ADC_POWER_PIN  AT91_PIN_PD14
#define ADC_CHACONF (MAX1098_CONF_START | MAX1098_CONF_PM_NORMAL | MAX1098_CONF_REF | MAX1098_CONV_START | channel)
#define ADCXMOD_MAJOR 63
#define ADCXMOD_MINOR 16
#endif

#define DEBUG(...) \
  printk("adcxmod - "__VA_ARGS__)

extern struct file_operations adcxmod_fops;


/* struct adcxmod_channel{ */
/*     unsigned short cmd; */
/* }; */

struct spi_adcxmod {
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
    int major;
    int minor;
    unsigned short cmd[NO_CHANNELS];
};

//static struct spi_adcxmod *priv = NULL;


static void spi_complete(void *data)
{
    struct spi_adcxmod *priv = (struct spi_adcxmod *)data;
    
    priv->spi_complete = 1;
    wake_up_interruptible(&priv->spi_queue);
    
}


irqreturn_t sstrb_interrupt(int irq, void *data)
{
    struct spi_adcxmod *priv = (struct spi_adcxmod *)data; 

    if( at91_get_gpio_value(AT91_PIN_PD18)){
        priv->samp_complete = 1;
        wake_up_interruptible(&priv->samp_queue);
    }

    return IRQ_HANDLED;
}

static int adcxmod_spi_trcve(struct spi_adcxmod *priv, unsigned short cmd, unsigned short *ret)
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

static short adcxmod_read_ad(struct spi_adcxmod *priv, int channel){
    
    unsigned short ret =0;
    int retval;
    
    if(down_interruptible(&priv->sem)){
        printk("semaphore wait interrupted\n");
        return -ERESTARTSYS;
    }

    priv->samp_complete = 0;

    retval =  adcxmod_spi_trcve(priv, priv->cmd[channel] , &ret);
    if(retval < 0){
        ret = retval;
        goto out;
    }

#ifdef ADC_SSTRB_PIN
    if( wait_event_interruptible(priv->samp_queue, priv->samp_complete)){ 
        printk("samp wait interrupted\n"); 
        ret = -ERESTARTSYS; 
        goto out;        
    } 
#endif
    retval =  adcxmod_spi_trcve(priv, 0, &ret);

    if(retval < 0){
        ret = retval;
        goto out;
    }

  out:
    up(&priv->sem);

    return ret;

}

static int adcxmod_open(struct inode *inode, struct file *filp)
{

    filp->private_data = (void*)inode;
    struct spi_adcxmod *priv = NULL;

    priv = container_of(inode->i_cdev, struct spi_adcxmod, dev);

    if (!try_module_get(adcxmod_fops.owner))  
	return -ENODEV;  
    
    return 0;
}

static int adcxmod_release(struct inode *inode, struct file *filep)
{
    module_put(adcxmod_fops.owner); 
    return 0;
}



static int adcxmod_ioctl(struct inode *inode, struct file *file,
                    unsigned int cmd, unsigned long arg)
{
    int retval = 0;


    printk(KERN_INFO "adcxmod module ioctl: %d, %lx\n", cmd, arg);

    return retval;
}



static ssize_t adcxmod_write(struct file *filp, const char *ubuf, 
                               size_t count, loff_t *offp)
{
    return count;
}



static ssize_t adcxmod_read(struct file *filp, char *ubuf, 
                              size_t count, loff_t *offp)
{
    struct inode *inode = (struct inode *)filp->private_data;
    struct spi_adcxmod *priv = NULL;
    int channel = 0; //iminor(inode) - ADCXMOD_MINOR;
    int ret = 0;
    char ascii[32];

    priv = container_of(inode->i_cdev, struct spi_adcxmod, dev);

    channel = iminor(inode) - priv->minor;

    if(channel < 0 || channel > NO_CHANNELS)
        return -EFAULT;

    ret = adcxmod_read_ad(priv, channel);

    sprintf(ascii, "%d\n", ret);

    if(copy_to_user(ubuf, ascii , strlen(ascii))){
        return -EFAULT;
    }

    return  strlen(ascii);

}


static unsigned int adcxmod_poll(struct file *filep, 
                                 struct poll_table_struct *wait)
{

	ulong mask = 0;
    
    printk(KERN_INFO "adcxmod poll\n");

    return mask;
}



struct file_operations adcxmod_fops =
{
	.owner   = THIS_MODULE,
    .open    = adcxmod_open,
    .release = adcxmod_release,
    .write   = adcxmod_write,
    .read    = adcxmod_read,
    .ioctl   = adcxmod_ioctl,
    .poll    = adcxmod_poll,
};


static int __devinit adcxmod_probe(struct spi_device *spi)
{
    int status = 0;
    int channel = 0;
    int err;
    dev_t devno;
    struct spi_adcxmod *priv = NULL;

    DEBUG("%s - probing for %s A/D converter\n", spi->dev.bus_id, ADC_NAME);
	


    priv = kzalloc(sizeof *priv, GFP_KERNEL);
    if (!priv)
	return -ENOMEM;

    priv->major = ADCXMOD_MAJOR;
    priv->minor = ADCXMOD_MINOR + spi->chip_select * NO_CHANNELS;

    init_MUTEX(&priv->sem);

    init_waitqueue_head(&priv->samp_queue);
    init_waitqueue_head(&priv->spi_queue);
    
    cdev_init(&priv->dev, &adcxmod_fops);
    priv->dev.owner = THIS_MODULE;
    priv->dev.ops   = &adcxmod_fops;
    
    devno = MKDEV(priv->major, priv->minor);
    
    printk (KERN_INFO "dev number %d %d\n", MAJOR(devno), MINOR(devno));
    
	err = cdev_add(&priv->dev, devno, NO_CHANNELS);
	if (err)
    {
		printk (KERN_NOTICE "Error %d adding mydots device\n", err);
        return err;
    }

    for(channel = 0; channel < NO_CHANNELS; channel++)    
        priv->cmd[channel] = ADC_CHACONF;

	priv->spi = spi;
  
	/* name must be usable with cmdlinepart */
	sprintf(priv->name, "spi%d.%d-%s",
          spi->master->bus_num, spi->chip_select,
          "adcxmod");

  /* Assign the priv data */
    dev_set_drvdata(&spi->dev, priv);
    
    /* Enable power for the analog inputs */
#ifdef ADC_POWER_PIN
    gpio_direction_output(ADC_POWER_PIN, 1);
#endif

    
    //   printk (KERN_INFO "interrupt requested\n");

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
    
    memset(&priv->spi_txbuf, 0xff, sizeof(priv->spi_txbuf));
    memset(&priv->spi_rxbuf, 0xff, sizeof(priv->spi_rxbuf));
    
    /* Command */
    priv->xfer.tx_buf = &priv->spi_txbuf;
    priv->xfer.rx_buf = &priv->spi_rxbuf;
    priv->xfer.len = 2;

    spi_message_add_tail(&priv->xfer, &priv->spi_msg);
    
#ifdef ADC_SSTRB_PIN
    /* Set the strobe pin to input */
    at91_set_gpio_input(ADC_SSTRB_PIN, 0);
    at91_set_deglitch(ADC_SSTRB_PIN, 1);
    if (request_irq(gpio_to_irq(ADC_SSTRB_PIN), 
                    sstrb_interrupt, 0, "adcstrb", (void*)priv)) { 
        printk("IRQ busy\n"); 
        return -EBUSY; 
    } 
#endif
  
  return status;
}

static int __devexit adcxmod_remove(struct spi_device *spi)
{
	struct spi_adcxmod *priv = dev_get_drvdata(&spi->dev);
	int	status = 0;

	DEBUG("%s - remove\n", spi->dev.bus_id);

#ifdef ADC_SSTRB_PIN
    disable_irq(gpio_to_irq(ADC_SSTRB_PIN)); 
    gpio_free(ADC_SSTRB_PIN); 
    free_irq(gpio_to_irq(ADC_SSTRB_PIN), (void*)priv); 
#endif


  /* Disable power for the analog inputs */
#ifdef ADC_POWER_PIN
  at91_set_gpio_input(ADC_POWER_PIN, 0);
#endif
  cdev_del(&priv->dev);

  kfree(priv);
	return status;
}

static struct spi_driver adcxmod_driver = {
	.driver = {
		.name		= ADC_NAME,
		.bus		= &spi_bus_type,
		.owner		= THIS_MODULE,
	},

	.probe		= adcxmod_probe,
	.remove		= __devexit_p(adcxmod_remove),

	/* FIXME:  investigate suspend and resume... */
};

static int __init adcxmod_init(void)
{
	return spi_register_driver(&adcxmod_driver);
}
module_init(adcxmod_init);

static void __exit adcxmod_exit(void)
{
	spi_unregister_driver(&adcxmod_driver);
}
module_exit(adcxmod_exit);

MODULE_DESCRIPTION(ADC_NAME "A/D module");
MODULE_AUTHOR("LIAB ApS. <http://www.liab.dk>");
MODULE_LICENSE("GPL");
