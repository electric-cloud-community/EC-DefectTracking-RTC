####################################################################
#
# ECDefectTracking::RTC::Cfg: Object definition of a Rational Team Concert Defect Tracking configuration.
#
####################################################################
package ECDefectTracking::RTC::Cfg;
@ISA = (ECDefectTracking::Base::Cfg);
if (!defined ECDefectTracking::Base::Cfg) {
    require ECDefectTracking::Base::Cfg;
}

####################################################################
# Object constructor for ECDefectTracking::RTC::Cfg
#
# Inputs
#   cmdr  = a previously initialized ElectricCommander handle
#   name  = a name for this configuration
####################################################################
sub new {
    my $class = shift;
	
    my $cmdr = shift;
    my $name = shift;
	
    my($self) = ECDefectTracking::Base::Cfg->new($cmdr,"$name");
    bless ($self, $class);
    return $self;
}


####################################################################
# RTCPORT
####################################################################
sub getRTCPORT {
    my ($self) = @_;
    return $self->get("RTCPORT");
}
sub setRTCPORT {
    my ($self, $name) = @_;
    print "Setting RTCPORT to $name\n";
    return $self->set("RTCPORT", "$name");
}

####################################################################
# Credential
####################################################################
sub getCredential {
    my ($self) = @_;
    return $self->get("Credential");
}
sub setCredential {
    my ($self, $name) = @_;
    print "Setting Credential to $name\n";
    return $self->set("Credential", "$name");
}

####################################################################
# validateCfg
####################################################################
sub validateCfg {
    my ($class, $pluginName, $opts) = @_;
    
	foreach my $key (keys % {$opts}) {
        print "\nkey=$key, val=$opts->{$key}\n";
    }
}

1;
