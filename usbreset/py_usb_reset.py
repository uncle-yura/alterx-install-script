#!/usr/bin/python
try:
        print "Reseting input devices"
	import time
	import sys
        from usb.core import find as finddev
        dev = finddev(idVendor=0x0483, idProduct=0x5750,find_all=True)
        for d in dev:
                #print d
	        d.reset()
	time.sleep(2)
	sys.exit(0)
except Exception, e:
        print "Input device reset error: %s" , e
	sys.exit(1)
