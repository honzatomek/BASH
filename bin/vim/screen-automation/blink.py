from machine import Pin
from utime import sleep_ms

# assign led to Pin
led = Pin(2, Pin.OUT, value=1)

#{{{ 1
for i in range(10):
    led.value(not led.value()) # swich led value
    print(i)
    sleep_ms(500)
#}}}

