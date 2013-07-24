GPX_PATH := util/GPX.git
SETPORTSPEED_PATH := util/setportspeed

.PHONY: $(GPX_PATH) $(SETPORTSPEED_PATH)

all:
	$(MAKE) -C $(GPX_PATH)
	$(MAKE) -C $(SETPORTSPEED_PATH)

clean:
	$(MAKE) -C $(GPX_PATH) clean
	$(MAKE) -C $(SETPORTSPEED_PATH) clean
