# Makefile

SRCTOP=..
include $(SRCTOP)/build/vars.mak

build: package

unittest:

systemtest: start-selenium test-setup test-run stop-selenium

NTESTFILES  ?= systemtest

test-setup:
	$(INSTALL_PLUGINS) EC-DefectTracking EC-DefectTracking-RTC

test-run: systemtest-run

include $(SRCTOP)/build/rules.mak

test: build install promote

install:
	ectool installPlugin ../../../out/common/nimbus/EC-DefectTracking-RTC/EC-DefectTracking-RTC.jar
 
promote:
	ectool promotePlugin EC-DefectTracking-RTC
