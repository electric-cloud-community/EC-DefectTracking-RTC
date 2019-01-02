####################################################################
#
# ECDefectTracking::RTC::Driver  Object to represent interactions with
#        RTC.
#
####################################################################
package ECDefectTracking::RTC::Driver;
@ISA = (ECDefectTracking::Base::Driver);
use ElectricCommander;
use Time::Local;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use File::stat;
use File::Temp;
use FindBin;
use Sys::Hostname;
use lib $ENV {'DEFECT_TRACKING_PERL_LIB'};

if ( !defined ECDefectTracking::Base::Driver )
{
    require ECDefectTracking::Base::Driver;
}
if ( !defined ECDefectTracking::RTC::Cfg )
{
    require ECDefectTracking::RTC::Cfg;
}
$| = 1;
####################################################################
# Object constructor for ECDefectTracking::RTC::Driver
#
# Inputs
#    cmdr          previously initialized ElectricCommander handle
#    name          name of this configuration
#
####################################################################
sub new
{
    my $this  = shift;
    my $class = ref($this) || $this;
    my $cmdr  = shift;
    my $name  = shift;
    my $cfg   = new ECDefectTracking::RTC::Cfg( $cmdr, "$name" );
    if ( "$name" ne '' )
    {
        my $sys = $cfg->getDefectTrackingPluginName();
        if ( "$sys" ne 'EC-DefectTracking-RTC' )
        {
            die "DefectTracking config $name is not type ECDefectTracking-RTC";
        }
    }
    my ($self) = new ECDefectTracking::Base::Driver( $cmdr, $cfg );
    bless( $self, $class );
    return $self;
}
####################################################################
# isImplemented
####################################################################
sub isImplemented
{
    my ( $self, $method ) = @_;
    if (    $method eq 'linkDefects'
         || $method eq 'updateDefects'
         || $method eq 'fileDefect'
         || $method eq 'createDefects' )
    {
        return 1;
    } else
    {
        return 0;
    }
}
####################################################################
# linkDefects
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub linkDefects
{
    my ( $self, $opts ) = @_;

    # get back a hash ref
    my $defectIDs_ref =
      $self->extractDefectIDsFromProperty( $opts->{propertyToParse},
                                           $opts->{prefix} );
    my $prefix = $opts->{prefix};
    print "Prefix: $prefix\n";
    if ( !keys %{$defectIDs_ref} )
    {
        print "No defect IDs found, returning\n";
        return;
    }
    $self->populatePropertySheetWithDefectIDs($defectIDs_ref);
    my $defectLinks_ref = {};
    my @bugs;
    my @instance;
    my $numb;
    @$numb = keys %$defectIDs_ref;
    s/$prefix// foreach @$numb;

    foreach my $id (@$numb)
    {
        $ENV{'RTCWORKITEM'} = $id;
        eval {
            my $rtcInstance = $self->getRTCInstance('QueryItem');
            @instance = split( '@@@@', $rtcInstance );
        };
        if ( $@ || $instance[1] == '' || ($instance[0] =~ m/^Error/) )
        {
            my $actualErrorMsg = $@;
            my $consoleError   = $instance[0];
            $consoleError =~
s/.*org.apache.commons.httpclient.HttpMethodDirector isAuthenticationNeeded\s+INFO: Authentication requested but doAuthentication is disabled\s+//i;
            print "Error failed trying to get RTC item = ID $id: ";
            print "$consoleError";
            $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                    'setProperty', "outcome", "error" );
        } else
        {
            my @bugs    = split( ';', $instance[1] );
            my $status  = $bugs[2];
            my $summary = $bugs[1];
            my $name    = "$prefix " . $bugs[0] . ": $summary, STATUS=$status";
            $name =~ s/\n//g;
            my $url =
                $self->getCfg()->get('url')
              . '/web/projects/'
              . $bugs[3]
              . '#action=com.ibm.team.workitem.viewWorkItem&id='
              . $bugs[0];
            print "Name: $name\n";
            if ( $name && $name ne '' && $url && $url ne '' )
            {
                $defectLinks_ref->{$name} = $url;
            }
        }
    }
    if ( keys %{$defectLinks_ref} )
    {
        $self->populatePropertySheetWithDefectLinks($defectLinks_ref);
        $self->createLinkToDefectReport("RTC Report");
    }
}
####################################################################
# updateDefects
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub updateDefects
{
    my ( $self, $opts ) = @_;

    # Attempt to read the property "/myJob/defectsToUpdate"
    # or the property entered as the "property" parameter to the subprocedure
    my $property = $opts->{property};
    if ( !$property || $property eq "" )
    {
        print "Error: Property does not exist or is empty\n";
        exit 1;
    }
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander( { SupressLog => 1, IgnoreError => 1 },
                              "getProperty", "$property" );
    if ($success)
    {
        my $value = $xpath->findvalue('//value')->string_value;
        $property = $value;
    } else
    {

        # log the error code and msg
        print "Error querying for $property as a property\n";
        exit 1;
    }

    # split using ',' to get a list of key=value pairs
    print "Property : $property\n";
    my @pairs = split( ',', $property );
    my $errors;
    my $updateddefectLinks_ref = {};    # ref to empty hash
    foreach my $val (@pairs)
    {
        print "Current Pair: $val\n";
        my ($idDefect, $action) = split( '=', $val );

        # the key of each pair is the defect ID,
        # e.g. "Defect10" is the first key in the example above

        # the value of each pair is the status,
        # e.g. "Resolved", is the first value in the example above

        # trim leading/trailing whitespace and remove "Defect" prefix
        $action =~ s/^\s+|\s+$//g;
        $idDefect =~ s/^\s+|\s+$//g;
        $idDefect =~ s/Defect//i;

        # extract the action and resolution
        my $resolution = '';
        if ($action =~ m/^(.*)\s*\:\s*(.*)\s*$/)
        {
            $action = $1;
            $resolution = $2;
        }
        print "id: $idDefect\n";
        print "  action: $action\n";
        print "    resolution: $resolution\n" if ($resolution);
        if (   !$idDefect
             || !$action )
        {
            print "Error: Item format error (id and action must be specified)\n";
            $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                    'setProperty', "outcome", "error" );
        } else
        {
            my $message = '';
            my @instance;
            $ENV{'RTCWORKITEM'}     = $idDefect;
            $ENV{'RTCACTION'}       = $action;
            $ENV{'RTCRESOLUTION'}   = $resolution;
            eval {
                my $rtcInstance =
                  $self->getRTCInstance("UpdateItem");
                @instance = split( '@@@@', $rtcInstance );
            };
            if ( $@ || $instance[1] == '' || ($instance[0] =~ m/^Error/) )
            {
                my $actualErrorMsg = $@;
                my $consoleError   = $instance[0];
                $consoleError =~
s/.*org.apache.commons.httpclient.HttpMethodDirector isAuthenticationNeeded\s+INFO: Authentication requested but doAuthentication is disabled\s+//i;
                $message =
"Error failed trying to update Defect $idDefect (action $action) status: $consoleError";
                print "$message";
                $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                        'setProperty', "outcome", "error" );
                $errors = 1;
            } else
            {
                my @bugs = split( ';', $instance[1] );
                my $status  = $bugs[2];
                my $summary = $bugs[1];
                my $name =
                  "WorkItem " . $bugs[0] . ": $summary, STATUS=$status";
                $name =~ s/\n//g;
                my $url =
                    $self->getCfg()->get('url')
                  . '/web/projects/'
                  . $bugs[3]
                  . '#action=com.ibm.team.workitem.viewWorkItem&id='
                  . $bugs[0];

                if ( $name && $name ne '' && $url && $url ne '' )
                {
                    $updateddefectLinks_ref->{$name} = $url;
                }
            }
        }
    }
    if ( keys %{$updateddefectLinks_ref} )
    {
        $propertyName_ref = 'updatedDefectLinks';
        $self->populatePropertySheetWithDefectLinks( $updateddefectLinks_ref,
                                                     $propertyName_ref );
        $self->createLinkToDefectReport("RTC Report");
    }
    if ( $errors && $errors ne '' )
    {
        print "Defects update completed with some Errors\n";
    }
}
####################################################################
# createDefects
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub createDefects
{
    my ( $self, $opts ) = @_;
    my $projectName = $opts->{rtcProjectName};
    if ( !$projectName || $projectName eq '' )
    {
        print "Error: rtcProjectName does not exist or is empty\n";
        exit 1;
    }

    #set property rtcProjectName, config for access on File Defect
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                              'setProperty', '/myJob/rtcProjectName',
                              "$projectName" );
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                              'setProperty', '/myJob/config',
                              "$opts->{config}" );
    my $mode = $opts->{mode};
    if ( !$mode || $mode eq '' )
    {
        print "Error: mode does not exist or is empty\n";
        exit 1;
    }
    ( $success, $xpath, $msg ) =
      $self->InvokeCommander(
                              { SupressLog => 1, IgnoreError => 1 },
                              'getProperties',
                              {
                                 recurse => '0',
                                 path    => '/myJob/ecTestFailures'
                              }
      );
    if ( !$success )
    {
        print "No Errors, so no Defects to create\n";
        return 0;
    }
    my $results = $xpath->find('//property');
    if ( !$results->isa('XML::XPath::NodeSet') )
    {

        # didn't get a nodeset
        print
          "Didn't get a NodeSet when querying for property: ecTestFailures \n";
        return 0;
    }
    my @propsNames = ();
    foreach my $context ( $results->get_nodelist )
    {
        my $propertyName = $xpath->find( './propertyName', $context );
        push( @propsNames, $propertyName );
    }
    my $createdDefectLinks_ref = {};    # ref to empty hash
    my $errors;
    foreach my $prop (@propsNames)
    {
        print "Trying to get Property /myJob/ecTestFailures/$prop \n";
        my ( $jSuccess, $jXpath, $jMsg ) =
          $self->InvokeCommander(
                                  { SupressLog => 1, IgnoreError => 1 },
                                  'getProperties',
                                  {
                                     recurse => '0',
                                     path    => "/myJob/ecTestFailures/$prop"
                                  }
          );
        my %testFailureProps = {};    # ref to empty hash
        ##Properties##
        #stepID
        my $stepID = "N/A";

        #testSuiteName
        my $testSuiteName = "N/A";

        #testCaseResult
        my $testCaseResult = "N/A";

        #testCaseName
        my $testCaseName = "N/A";

        #logs
        my $logs = "N/A";

        #stepName
        my $stepName = "N/A";
        my $jResults = $jXpath->find('//property');
        foreach my $jContext ( $jResults->get_nodelist )
        {
            my $subPropertyName =
              $jXpath->find( './propertyName', $jContext )->string_value;
            my $value = $jXpath->find( './value', $jContext )->string_value;
            if ( $subPropertyName eq "stepId" ) { $stepID = $value; }
            if ( $subPropertyName eq "testSuiteName" ) {
                $testSuiteName = $value;
            }
            if ( $subPropertyName eq "testCaseResult" )
            {
                $testCaseResult = $value;
            }
            if ( $subPropertyName eq "testCaseName" ) {
                $testCaseName = $value;
            }
            if ( $subPropertyName eq "logs" )     { $logs     = $value; }
            if ( $subPropertyName eq "stepName" ) { $stepName = $value; }
        }
        my @instance;
        my $message = "";
        my $comment =
            "Step ID: $stepID "
          . "Step Name: $stepName "
          . "Test Case Name: $testCaseName ";
        if ( $mode eq 'automatic' )
        {
            eval {
                my $cfg     = $self->getCfg();
                $ENV{'RTCPROJECTAREA'}  = $cfg->get('project');
                $ENV{'RTCSUMMARY'}      = $comment;
                $ENV{'RTCDESCRIPTION'}  = $comment;
                $ENV{'RTCWORKITEMTYPE'} = 'defect';
                my $rtcInstance =
				  $self->getRTCInstance("AddItem");
                @instance = split( '@@@@', $rtcInstance );
                my @bugs = split( ';', $instance[1] );
                $bugs[0] =~ s/\s//g;
                $message = 'WorkItem Created with ID: ' . $bugs[0] . "\n";
                my $defectUrl =
                    $self->getCfg()->get('url')
                  . '/web/projects/'
                  . $bugs[3]
                  . '#action=com.ibm.team.workitem.viewWorkItem&id='
                  . $bugs[0];
                $createdDefectLinks_ref->{"$comment"} =
                  "$message?url=$defectUrl";
            };
            if ($@ || $instance[1] == '' || ($instance[0] =~ m/^Error/) )
            {
                my $actualErrorMsg = $@;
                my $consoleError   = $instance[0];
                $consoleError =~
s/.*org.apache.commons.httpclient.HttpMethodDirector isAuthenticationNeeded\s+INFO: Authentication requested but doAuthentication is disabled\s+//i;
                $message =
                  "Error failed trying to create workitem: $consoleError";
                $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                        'setProperty', "outcome", "error" );
                $errors = 1;
                $createdDefectLinks_ref->{"$comment"} = "$message?prop=$prop";
            }
            print "$message";
        } else
        {    #$mode eq "manual"
            $createdDefectLinks_ref->{"$comment"} =
              "Needs to File Defect?prop=$prop";
        }
    }
    if ( keys %{$createdDefectLinks_ref} )
    {
        $propertyName_ref = "createdDefectLinks";
        $self->populatePropertySheetWithDefectLinks( $createdDefectLinks_ref,
                                                     $propertyName_ref );
        $self->createLinkToDefectReport("RTC Report");
    }
    if ( $errors && $errors ne "" )
    {
        print "Created Defects completed with some Errors\n";
    }
}
####################################################################
# fileDefect
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub fileDefect
{
    my ( $self, $opts ) = @_;
    my $prop = $opts->{prop};
    if ( !$prop || $prop eq '' )
    {
        print "Error: prop does not exist or is empty\n";
        exit 1;
    }
    my $jobIdParam = $opts->{jobIdParam};
    if ( !$jobIdParam || $jobIdParam eq '' )
    {
        print "Error: jobIdParam does not exist or is empty\n";
        exit 1;
    }
    my $projectNameParam;
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander(
                              { SupressLog => 1, IgnoreError => 1 },
                              "getProperty",
                              "rtcProjectName",
                              { jobId => "$jobIdParam" }
      );
    if ($success)
    {
        $projectNameParam = $xpath->findvalue('//value')->string_value;
    } else
    {

        # log the error code and msg
        print "Error: projectNameParam does not exist or is empty\n";
        exit 1;
    }
    print "Trying to get Property /$jobIdParam/ecTestFailures/$prop \n";
    my ( $jSuccess, $jXpath, $jMsg ) =
      $self->InvokeCommander(
                              { SupressLog => 1, IgnoreError => 1 },
                              'getProperties',
                              {
                                 recurse => '0',
                                 jobId   => "$jobIdParam",
                                 path    => "/myJob/ecTestFailures/$prop"
                              }
      );
    ##Properties##
    #stepID
    my $stepID = "N/A";

    #testSuiteName
    my $testSuiteName = "N/A";

    #testCaseResult
    my $testCaseResult = "N/A";

    #testCaseName
    my $testCaseName = "N/A";

    #logs
    my $logs = "N/A";

    #stepName
    my $stepName = "N/A";
    my $jResults = $jXpath->find('//property');
    foreach my $jContext ( $jResults->get_nodelist )
    {
        my $subPropertyName =
          $jXpath->find( './propertyName', $jContext )->string_value;
        my $value = $jXpath->find( './value', $jContext )->string_value;
        if ( $subPropertyName eq 'stepId' )        { $stepID        = $value; }
        if ( $subPropertyName eq 'testSuiteName' ) { $testSuiteName = $value; }
        if ( $subPropertyName eq 'testCaseResult' ) {
            $testCaseResult = $value;
        }
        if ( $subPropertyName eq 'testCaseName' ) { $testCaseName = $value; }
        if ( $subPropertyName eq 'logs' )         { $logs         = $value; }
        if ( $subPropertyName eq 'stepName' )     { $stepName     = $value; }
    }
    my @instance;
    my $message = "";
    my $comment =
        "Step ID: $stepID "
      . "Step Name: $stepName "
      . "Test Case Name: $testCaseName ";
    eval {
        my $cfg     = $self->getCfg();
        $ENV{'RTCPROJECTAREA'}  = $cfg->get('project');
        $ENV{'RTCSUMMARY'}      = $comment;
        $ENV{'RTCDESCRIPTION'}  = $comment;
        $ENV{'RTCWORKITEMTYPE'} = 'defect';
        my $rtcInstance =
          $self->getRTCInstance('AddItem');
        @instance = split( '@@@@', $rtcInstance );
        my @bugs = split(';', $instance[1]);
        $bugs[0] =~ s/\s//g;
        $message = "WorkItem Created with ID: " . $bugs[0] . "\n";
        my ( $success, $xpath, $msg ) =
          $self->InvokeCommander(
                                  { SuppressLog => 1, IgnoreError => 1 },
                                  "setProperty",
                                  "/myJob/ecTestFailures/$prop/defectId",
                                  "@bugs[0]",
                                  { jobId => "$jobIdParam" }
          );
        my $defectUrl =
            $self->getCfg()->get("url")
          . "/web/projects/"
          . $bugs[3]
          . "#action=com.ibm.team.workitem.viewWorkItem&id="
          . $bugs[0];
        my ( $success, $xpath, $msg ) =
          $self->InvokeCommander(
                                  { SuppressLog => 1, IgnoreError => 1 },
                                  "setProperty",
                                  "/myJob/createdDefectLinks/$comment",
                                  "$message?url=$defectUrl",
                                  { jobId => "$jobIdParam" }
          );
    };
    if ($@ || $instance[1] == '' || ($instance[0] =~ m/^Error/) )
    {
        print "Project Name: $projectNameParam\n";
        my $consoleError = $instance[0];
        $consoleError =~
s/.*org.apache.commons.httpclient.HttpMethodDirector isAuthenticationNeeded\s+INFO: Authentication requested but doAuthentication is disabled\s+//i;
        $message = "Error failed trying to create workitem: $@ $consoleError";
        $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                'setProperty', "outcome", "error" );
        print
"setProperty name: /$jobIdParam/createdDefectLinks/$comment value:$message?prop=$prop \n";
        my ( $success, $xpath, $msg ) =
          $self->InvokeCommander(
                                  { SuppressLog => 1, IgnoreError => 1 },
                                  'setProperty',
                                  "/myJob/createdDefectLinks/$comment",
                                  "$message?prop=$prop",
                                  { jobId => "$jobIdParam" }
          );
    }
    print "$message";
}
####################################################################
# getRTCInstance
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#
# Returns:
#   A RTC instance used to do operations on a RTC server.
####################################################################
sub getRTCInstance
{
    my ( $self, $command ) = @_;
    my $cfg            = $self->getCfg();
    my $url            = $cfg->get('url');
    my $credentialName = $cfg->getCredential();
    my $credentialLocation =
      q{/projects/$[/plugins/EC-DefectTracking/project]/credentials/}
      . $credentialName;
    my ( $success, $xPath, $msg ) =
      $self->InvokeCommander( { SupressLog => 1, IgnoreError => 1 },
                              'getFullCredential', $credentialLocation );
    if ( !$success )
    {
        print "\nError getting credential\n";
        return;
    }
    my $rtcuser = $xPath->findvalue('//userName')->value();
    my $passwd  = $xPath->findvalue('//password')->value();
    if ( !$rtcuser || !$passwd )
    {
        print
"User name and or password in credential $credentialLocation is not set\n";
        return;
    }

# NB: The helper (and related jar files) live in the RTC plugin agent directory.
# For example:
# $COMMANDER_PLUGINS/EC-DefectTracking-RTC-1.2.3.45678/
#        agent/
#            RTC_Console.jar
#            RTC-Client-plainJavaLib-4.0.2/
#                <numerous-jar-files>
# It is the responsibility of the customer to download and install the RTC runtime
# Java libraries into the RTC-Client-plainJavaLib-x.x.x directory.
#
# Note that the command lines will be different between Windows and Linux.

    # Compute a path to the plugin helper agent folder
    my $p = $ENV {'DEFECT_TRACKING_PERL_LIB'};
    $p =~ s|/lib|/agent|;
    # Compute the path to the Commander java command
    my $j = $ENV{'COMMANDER_HOME'} . '/jre/bin/java';
    # Build the command line
    my $c = '';
    my $passwordStart;
    my $passwordLength;
    # Switch based on host type
    if ($^O =~ m/Win/) {
            $c = $j . '.exe';
            # Can't start a command that may have multiple quoted chunks
            # with a double-quote character, so isolate the drive letter
            # of the path and double-quote the rest.  Ugly.
            $c =~ s|^(.\:)(.*)$|$1\"$2\"|;
            # Tack on the jar file reference.  Double-quote that path.
            $c .= " -jar \"$p/RTC_Console.jar\"";
            # Now tack on the user name.  Pretty safe to double-quote that.
            $c .= " \"$rtcuser\" ";
        $passwordStart = length($c);
            # Now the password - any number of special characters may be
            # here, so use the caret technique instead:
            $passwd =~ s|(.)|\^$1|g;
            $c .= $passwd;
        $passwordLength = length($c) - $passwordStart;      
    } else {
            $c = "\"$j\" -jar \"$p/RTC_Console.jar\"";
            # Now tack on the user name.  Pretty safe to double-quote that.
            $c .= " \"$rtcuser\" ";
        $passwordStart = length($c);
            # Now the password - any number of special characters may be
            # here, no good way to sort that all out. Escape any backslashes,
            # and then escape any single quotes.  That should do it. Ick.
            $passwd =~ s|\\|\\\\|g;
            $passwd =~ s|\'|\\\'|g;
            $c .= "'$passwd'";
        $passwordLength = length($c) - $passwordStart;
    }
    # Double quote the URL and add that too.
    $c .= " \"$url\"";
    # Assemble the final command line
    $command = "$c $command 2>&1";
#
# End of modification
    my $instance;
    eval {
        $instance = $self->RunCommand(
                                       $command,
                                       {
                                          LogCommand     => 1,
                                          LogResult      => 1,
                                          HidePassword   => 1,
                                          passwordStart  => $passwordStart,
                                          passwordLength => $passwordLength
                                       }
        );
    };
    return $instance;
}
####################################################################
# addConfigItems
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   nothing
####################################################################
sub addConfigItems {

    my ($self, $opts) = @_;

    $opts->{'linkDefects_label'}       = "RTC Report";
    $opts->{'linkDefects_description'} = "Generates a report of RTC IDs found in the build.";

}

# Added by BHandley 3/22/13 to support updated java interface by MWesterhof
####################################################################
# dumpItemInfo
#
# Retrieves info about the RTC workItem specified 
# Retrieved data includes the workitemType, ProjectArea, currentState, defined
# states and their mapping from numeric, enumerated values to text labels, 
# defined actions, and defined resolutions and their mapping from numberic
# to text values.
#
# This procedure is intended to be called as a debugging tool to dump out the 
# the valid states, actions and resolutions for a particular item.
#
# The retrieved data is dumped to STDOUT
# 
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   nothing
####################################################################
sub dumpItemInfo
{
    my ( $self, $opts ) = @_;
    my $itemId = $opts->{'itemId'};
    
    print "Driver version $::RTCdriverVersion\n";
    print "Dumping Item Info for RTC workItem $itemId\n";
    
    $ENV{'RTCWORKITEM'} = $itemId;
    #my $shellEnv = `set`;
    #print "local shell ENV is:\n$shellEnv\n";
    my $rtcInstance = $self->getRTCInstance('DumpInfo');    
}

# Added by BHandley 3/23/13 to support updated java interface by MWesterhof
####################################################################
# addWorkItem
#
# Add/create a new workItem
#
# Uses the config, rtcProjectName, Summary, Description, LinkText and LinkURI params
#
# 
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   nothing
####################################################################
sub addWorkItem
{
    my ( $self, $opts ) = @_;
    my $projectName = $opts->{"rtcProjectName"};
    my $Summary = $opts->{"Summary"};
    my $Description = $opts->{"Description"};
    my $LinkText = $opts->{"LinkText"};
    my $LinkURI = $opts->{"LinkURI"};            
    
    print "Creating/adding a new workItem\n";
    print "\tRTC Project Area: $projectName\n";    
    print "\tworkItem Summary: $Summary\n";
    print "\tworkItem Description: $Description\n";
    print "\tworkItem Link Text: $LinkText\n";
    print "\tworkItem Link URI: $LinkURI\n"; 
    
    # Validate the LinkText and LinkURI params
    # If either is specified, then BOTH must be specified
    if ( (($LinkText ne "") && ($LinkURI eq "")) || (($LinkURI ne "") && ($LinkText eq "")) ){
      print "Error: If either Link Text or Link URI is specified, then BOTH must be specified\n";
      exit(1);
    }    
    
    $ENV{'RTCPROJECTAREA'}  = $projectName;
    $ENV{'RTCSUMMARY'}      = $Summary;
    $ENV{'RTCDESCRIPTION'}  = $Description;
    $ENV{'RTCLINK_RA_TEXT'} = $LinkText;
    $ENV{'RTCLINK_RA_URI'}  = $LinkURI;
                
    # Hard-code workitem type for now - MJW
    $ENV{'RTCWORKITEMTYPE'} = 'defect';

    #my $shellEnv = `set`;
    #print "local shell ENV is:\n$shellEnv\n";
    my $rtcInstance = $self->getRTCInstance("AddItem");    
}

# Added by BHandley 3/23/13 to support updated java interface by MWesterhof
####################################################################
# updateWorkItem
#
# Update an existing  workItem
#
# Uses the config, workItemNumber, Action, Resolution, LinkText and LinkURI params
#
# 
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   nothing
####################################################################
sub updateWorkItem
{
    my ( $self, $opts ) = @_;
    my $workItem = $opts->{"workItemNumber"};
    my $Action = $opts->{"Action"};
    my $Resolution = $opts->{"Resolution"};
    my $LinkText = $opts->{"LinkText"};
    my $LinkURI = $opts->{"LinkURI"};            
    
    print "Updating workItem: $workItem\n";
    print "\tAction: $Action\n";    
    print "\tResolution: $Resolution\n";
    print "\tworkItem Link Text: $LinkText\n";
    print "\tworkItem Link URI: $LinkURI\n"; 
    
    # Validate the LinkText and LinkURI params
    # If either is specified, then BOTH must be specified
    if ( (($LinkText ne "") && ($LinkURI eq "")) || (($LinkURI ne "") && ($LinkText eq "")) ){
      print "Error: If either Link Text or Link URI is specified, then BOTH must be specified\n";
      exit(1);
    }
    
    # Validate the Action and Resolution params
    # Resolution can only be specified if an Action is specified
    if ( ($Resolution ne "") && ($Action eq "") ){
      print "Error: Resolution can only be specified if an Action is specified\n";
      exit(1);
    }    
    
    $ENV{'RTCWORKITEM'}     = "$workItem";    
    $ENV{'RTCACTION'}       = "$Action";
    $ENV{'RTCRESOLUTION'}   = "$Resolution";
    $ENV{'RTCLINK_RA_TEXT'} = "$LinkText";
    $ENV{'RTCLINK_RA_URI'}  = "$LinkURI";
                
    #my $shellEnv = `set`;
    #print "local shell ENV is:\n$shellEnv\n";
    my $rtcInstance = $self->getRTCInstance("UpdateItem");    
}

1;
