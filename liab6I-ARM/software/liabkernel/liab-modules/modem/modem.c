#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/interrupt.h>
#include <linux/irq.h>
#include <linux/time.h>
#include <linux/io.h>
#include <mach/hardware.h>
#include <linux/platform_device.h>
#include <linux/mutex.h>
#include <linux/device.h>
#include <linux/ctype.h>
#include <linux/err.h>
#include <asm/delay.h>

#include <linux/sysdev.h>

#include <linux/at91_pwm.h>

#include <asm/io.h>
#include <asm/irq.h>
#include <asm/gpio.h>
#include <mach/at91_tc.h>

#define MODEM_TIMER_STEP 60
#define MODEM_STEP_INTERVAL 2 // jiffies

#define to_modem_device(obj) container_of(obj, struct liabdin_modem, dev)

/*
#define DEBUG(...) \
  printk("modem - "__VA_ARGS__)
*/

#define DEBUG(...)

enum eModemState {MODEM_OFF, MODEM_ON, MODEM_BUSY};

struct liabdin_modem {
  struct timer_list timer;
  struct timer_list ig_timer;
  struct mutex lock;
  enum eModemState power;
  enum eModemState ignite;
  int timer_steps;
  int step;
  struct device dev;
  struct pwm_channel	pwmc;
};

struct liabdin_class {
  struct liabdin_modem *modem_dev;  
};

static struct class *liab_class;

#define PWM_PERIOD 254
#define PWM_STEP (254/MODEM_TIMER_STEP)

static void liabdin_power_timer(unsigned long data)
{
  struct liabdin_modem *priv;  
  priv = (struct liabdin_modem *)data;

  if(priv->step > 0) {
    mod_timer(&priv->timer, jiffies +  MODEM_STEP_INTERVAL);
    pwm_channel_writel(&priv->pwmc, PWM_CUPD, priv->step*PWM_STEP);
    priv->step--;
    if(priv->step == 0)
      at91_set_gpio_output(AT91_PIN_PA19, 1);
  } else {
    priv->power = MODEM_ON;
    del_timer(&priv->timer);
    DEBUG(" Done\n"); 
  }
}

static ssize_t liabdin_modem_show_power(struct device *dev,
		struct device_attribute *attr,char *buf)
{
  struct liabdin_modem *priv = to_modem_device(dev);
  
  if(priv->power == MODEM_BUSY)
    return sprintf(buf, "0\n");
  else
    return sprintf(buf, "%d\n", priv->power);
}

static ssize_t liabdin_modem_store_power(struct device *dev,
		struct device_attribute *attr, const char *buf, size_t count)
{
  struct liabdin_modem *priv=  to_modem_device(dev);
  int rc;
  unsigned long power;

	rc = strict_strtoul(buf, 0, &power);
	if (rc)
		return rc;

  rc = -ENXIO;

  DEBUG("%d -  power = %ld\n", __LINE__, power);

  mutex_lock(&priv->lock);
  if(power > 0 && priv->power == MODEM_OFF) { 
    DEBUG("%d -  staring modem\n", __LINE__);
    priv->power = MODEM_BUSY;
    priv->step = priv->timer_steps;

    pwm_channel_enable(&priv->pwmc);
    pwm_channel_writel(&priv->pwmc, PWM_CUPD, 254);
    at91_set_B_periph(AT91_PIN_PA19, 0);
    
    add_timer(&priv->timer);
    mod_timer(&priv->timer, jiffies +  MODEM_STEP_INTERVAL);    
  } else {
    priv->power = MODEM_OFF;
    priv->ignite = MODEM_OFF;
    pwm_channel_disable(&priv->pwmc);
    at91_set_gpio_output(AT91_PIN_PA19, 0);
    DEBUG("%d -  turning off modem\n", __LINE__);
  }
  rc = count;
  mutex_unlock(&priv->lock);

	return rc;
}

static void liabdin_ignite_timer(unsigned long data)
{
  struct liabdin_modem *priv;  
  priv = (struct liabdin_modem *)data;

  at91_set_gpio_output(AT91_PIN_PB28, 0);
  priv->ignite = MODEM_ON;
  del_timer(&priv->timer);
  DEBUG(" Done\n"); 
}

static ssize_t liabdin_modem_show_ignite(struct device *dev,
		struct device_attribute *attr,char *buf)
{
  struct liabdin_modem *priv = to_modem_device(dev);
  
  if(priv->ignite == MODEM_BUSY)
    return sprintf(buf, "0\n");
  else
    return sprintf(buf, "%d\n", priv->ignite);
}

static ssize_t liabdin_modem_store_ignite(struct device *dev,
		struct device_attribute *attr, const char *buf, size_t count)
{
  struct liabdin_modem *priv=  to_modem_device(dev);
  int rc;
  unsigned long ignite;
  int i;

	rc = strict_strtoul(buf, 0, &ignite);
	if (rc)
		return rc;

  rc = -ENXIO;

  DEBUG("%d -  priv->power = %d   priv->ignite = %d ignite = %ld\n", __LINE__, 
        priv->power, 
        priv->ignite, 
        ignite);

  mutex_lock(&priv->lock);
  if(priv->power == MODEM_ON && 
     priv->ignite == MODEM_OFF && 
     ignite > 0) { 
    DEBUG("%d -  igniting modem\n", __LINE__);
    priv->ignite = MODEM_BUSY;
    at91_set_gpio_output(AT91_PIN_PB28, 0);
    at91_set_gpio_output(AT91_PIN_PB28, 1);
    add_timer(&priv->ig_timer);
    mod_timer(&priv->ig_timer, jiffies +  30);
  }

  rc = count;
  mutex_unlock(&priv->lock);

	return rc;
}

static void liabdin_modem_device_release(struct device *dev)
{
  struct liabdin_modem *priv=  to_modem_device(dev);  
	kfree(priv);

  DEBUG("device released\n");
}

static int __devinit liabdin_modem_probe(struct platform_device *pdev)
{
  struct liabdin_modem *modem_dev;
  struct liabdin_class *lc;

  int rc;

	DEBUG("%d - loading modem module\n", __LINE__);

  /* Setup the driver data... */
	lc = kzalloc(sizeof(struct liabdin_class), GFP_KERNEL);
	if (!lc)
		return -ENOMEM;

  platform_set_drvdata(pdev, lc);

  /* Register a device */
	modem_dev = kzalloc(sizeof(struct liabdin_modem), GFP_KERNEL);
	if (!modem_dev)
		return -ENOMEM;


  modem_dev->power       = MODEM_OFF;
  modem_dev->ignite      = MODEM_OFF;
  modem_dev->timer_steps = MODEM_TIMER_STEP;
  modem_dev->step        = MODEM_TIMER_STEP;

  modem_dev->dev.class   = liab_class;
  modem_dev->dev.parent  = &pdev->dev;
  modem_dev->dev.release = liabdin_modem_device_release;

  setup_timer(&modem_dev->timer, liabdin_power_timer, (unsigned long)modem_dev);
  setup_timer(&modem_dev->ig_timer, liabdin_ignite_timer, (unsigned long)modem_dev);
  mutex_init(&modem_dev->lock);

  lc->modem_dev = modem_dev;

  dev_set_name(&modem_dev->dev, "modem");
  
	rc = device_register(&modem_dev->dev);
	if (rc) {
    DEBUG("Error registering device\n");
		kfree(modem_dev);
		return rc;
	}

  rc = pwm_channel_alloc(AT91_PIN_PA19, &modem_dev->pwmc);
  if (rc < 0) {
    DEBUG("Error allocating PWM channel\n");
		kfree(modem_dev);
		return rc;
	}

  /* Disable the output */
  at91_set_gpio_output(AT91_PIN_PA19, 0);

  /* PB28 is the ignite - PD23 is emerg off both are active low */
  at91_set_gpio_output(AT91_PIN_PB28, 0);
  at91_set_gpio_output(AT91_PIN_PD23, 0);
  
  
	DEBUG("%d - Load done\n", __LINE__);
  
	return 0;
}

static int __devexit liabdin_modem_remove(struct platform_device *pdev)
{
  struct liabdin_class *priv = dev_get_drvdata(&pdev->dev);

  device_unregister(&priv->modem_dev->dev);
	DEBUG("remove\n");
  //del_timer(&priv->timer);
  /* Turn off the modem */
  at91_set_gpio_output(AT91_PIN_PA19, 0);
  kfree(priv);
	return 0;
}



static struct platform_driver liabdin_modem_driver = {
	.remove		= __exit_p(liabdin_modem_remove),
	.driver		= {
		.name	= "liabdin_modem",
		.owner	= THIS_MODULE,
	},
};



static struct device_attribute liabdin_modem_device_attributes[] = {
	__ATTR(power, 0644, liabdin_modem_show_power, liabdin_modem_store_power),
	__ATTR(ignite, 0644, liabdin_modem_show_ignite, liabdin_modem_store_ignite),
	__ATTR_NULL,
};


static int __init liabdin_modem_init(void)
{
	liab_class = class_create(THIS_MODULE, "liab");
	if (IS_ERR(liab_class)) {
		printk(KERN_WARNING "Unable to create liab class; errno = %ld\n",
				PTR_ERR(liab_class));
		return PTR_ERR(liab_class);
	}

  liab_class->dev_attrs = liabdin_modem_device_attributes;

  return platform_driver_probe(&liabdin_modem_driver, liabdin_modem_probe);
}

static void __exit liabdin_modem_exit(void)
{
  class_destroy(liab_class);
  platform_driver_unregister(&liabdin_modem_driver);
}

module_init(liabdin_modem_init);
module_exit(liabdin_modem_exit);

MODULE_DESCRIPTION("LIABDIN modem module");
MODULE_AUTHOR("LIAB ApS. <http://www.liab.dk>");
MODULE_LICENSE("GPL");
