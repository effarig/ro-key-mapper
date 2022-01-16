DATE 	= $(Sys$Date) $(Sys$Year)
ASFLAGS = -PreDefine "BUILDDATE SETS \"$(DATE)\"" -throwback
AS   	= objasm $(ASFLAGS) -o $@ $*.s
LINK 	= link -rmf -o $@ $<
LIBS 	=
DEPS 	=
OBJS 	= module.o
MODNAME = KeyMapper
MODFILE = KeyMapper
TGT  	= rm.$(MODFILE)
RELEASEDIR = Dist
ZIPDIST = keymapper/zip
MODDIST = !System.350.Modules.$(MODFILE)
INSTALL = <System$Dir>.350.Modules.$(MODFILE)
DIST    = !System !ReadMe LICENSE

all: $(TGT)

run: $(TGT)
	@echo Killing $(MODNAME)...
	@-RMKill $(MODNAME)
	@echo Loading $(MODNAME)...
	@RMLoad $(TGT)


dist: $(TGT)
	@echo Removing previous distribution archive and directory...
	@remove $(ZIPDIST)
	@-wipe ${RELEASEDIR} F~VR~C
	@echo Creating target directories
	@cdir ${RELEASEDIR}
	@cdir ${RELEASEDIR}.!System
	@cdir ${RELEASEDIR}.!System.350
	@cdir ${RELEASEDIR}.!System.350.Modules
	@echo Copying $(TGT) to $(MODDIST)
	@copy $(TGT) ${RELEASEDIR}.$(MODDIST) A~CF~L~N~P~QR~S~T~V
	@copy !ReadMe ${RELEASEDIR}.!ReadMe A~CF~L~N~P~QR~S~T~V
	@copy LICENSE ${RELEASEDIR}.LICENSE A~CF~L~N~P~QR~S~T~V
	@echo Zipping as $(ZIPDIST)...
	@dir ${RELEASEDIR}
	@zip -9 -r \.$(ZIPDIST) $(DIST)
	@back
	@echo Done.

clean:
	@echo removing target module...
	@-wipe rm F~VR~C
	@echo removing object files...
	@-wipe o F~VR~C
	@echo removing dist directory...
	@-wipe ${RELEASEDIR}  F~VR~C
	@echo removing dist zip...
	@-wipe $(ZIPDIST)  F~VR~C

install: $(TGT)
	@echo Install location: $(INSTALL)
	@echo Removing previously installed version.
	@-wipe $(INSTALL) F~VR~C
	@echo Installing new version.
	@copy $(TGT) $(INSTALL) A~CF~L~N~P~QR~S~T~V
	@count $(INSTALL)

uninstall:
	@echo Removing previously installed version.
	@-wipe $(INSTALL) F~VR~C

dirs:
	@cdir o
	@cdir rm

$(OBJS): $(DEPS) dirs

$(TGT): $(OBJS)
	@echo Linking $*...
	@$(LINK) $(OBJS) $(LIBS)

.SUFFIXES: .o .s

.s.o:
	@echo Assembling $*...
	@$(AS)
