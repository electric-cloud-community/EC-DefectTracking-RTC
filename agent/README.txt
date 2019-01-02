                              IMPORTANT NOTICE
                              ----------------

In order to use this plugin, you must install the correct version of the
Rational RTC Client Java libraries.  Due to licensing restrictions, these
libraries cannot be distributed by Electric Cloud as part of the plugin.

This Electric Cloud plugin was built against version 4.0.2 of the RTC
Client Java libraries, and therefore you must install exactly that version
of the RTC Client Java libraries; no other version, neither older nor newer,
will work.

1) Download the "RTC-Client-plainJavaLib-4.0.2.zip" file from IBM's web site:

https://jazz.net/downloads/rational-team-concert/releases/4.0.2/RTC-Client-plainJavaLib-4.0.2.zip

2) Copy the zip file to the "agent/RTC-Client-plainJavaLib-4.0.2" folder
in the this plugin and extract the contents.  The exact path to this plugin's
on-disk folder will vary depending on the version of the plugin (however, the
fact that you are reading this document implies that you've found that location
-- this README.txt file is normally located in the plugin's "agent" folder.

General instructions for locating the on-disk folder for a plugin:

  - determine where plugins are installed in your system (the examples below
    assume the default installation location).

  - navigate to the Admin->Plugins tab on the Commander Web UI to get the full
    name, with version numbers, of the plugin.  Note that there may be multiple
    versions of the plugin -- the one of interest is usually the one marked as
    "promoted" in the GUI.

  - cd to your plugins folder. The default location of the plugin folder is
    "plugins" in the Commander data (install) directory.  If you have a default
    installation on Linux, for example, cd to:
      /opt/electriccloud/electriccommander/plugins

  - cd into the plugin's RTC Client Java Library  folder. For example, if your
    full plugin version is "2.1.0.98765" (determined from the Admin->Plugins
    tab step, above), then cd to:
      EC-DefectTracking-RTC-2.1.0.98765/agent/RTC-Client-plainJavaLib-4.0.2

  - extract the contents of the downloaded RTC-Client-plainJavaLib-4.0.2.zip
    file to the folder.

  - finally, confirm that the extracted jar files are readable by the user id
    that the agent(s) are running as.  On a Linux system, this can easily be
    accomplished with the chmod command:
      chmod a+rx *.jar

3) In order to test that the libraries are correctly installed:

  - cd to the "agent" folder (up one level if you've just completed step 2).

  - determine the path to the Commander-provided jre.  If you have a default
    installation, this is in the "jre" folder in the install directory.  For
    example, on a standard Linux installation, the path would be:
      /opt/electriccloud/electriccommander/jre

  - execute the RTC Console application using the Commander-provided jre. On
    a standard Linux installation, simply type:
      /opt/electriccloud/electriccommander/jre/bin/java -jar RTC_Console.jar

  - confirm the expected output. You should see usage instructions, similar
    to the output below, being printed by the application:
      Error: insufficient command-line arguments.
      Usage:
       RTC_Console <userid> <passwd> <repoURI> AddItem
       RTC_Console <userid> <passwd> <repoURI> QueryItem
       RTC_Console <userid> <passwd> <repoURI> UpdateItem
       RTC_Console <userid> <passwd> <repoURI> DumpInfo

  - if you see output similar to the below output, then something has gone
    wrong with the installation of the RTC Libraries.  Check the above steps
    and confirm that you have correctly installed the jar files, with the
    correct permissions, into the correct location on-disk.
      Exception in thread "main" java.lang.NoClassDefFoundError: org/eclipse/core/runtime/AssertionFailedException
              at java.lang.Class.getDeclaredMethods0(Native Method)
              at java.lang.Class.privateGetDeclaredMethods(Class.java:2451)
              at java.lang.Class.getMethod0(Class.java:2694)
              at java.lang.Class.getMethod(Class.java:1622)
              at sun.launcher.LauncherHelper.getMainMethod(LauncherHelper.java:494)
              at sun.launcher.LauncherHelper.checkAndLoadMain(LauncherHelper.java:486)
      Caused by: java.lang.ClassNotFoundException: org.eclipse.core.runtime.AssertionFailedException

4) (Optional) Test your connectivity and credentials using the "DumpInfo"
   function of the RTC_Console application.  You will require the correct URL
   to your RTC server, as well as a valid RTC user id and password (this
   should be the same information you use to create the RTC Defect Tracking
   configuration in the ElectricCommander Web UI).  You will also need a
   valid work item number in your RTC system.  For example, assuming that
   work item "12" is valid, you would execute the following command. (Note:
   the command is all on a single line; it may appear wrapped in this file.)
      /opt/electriccloud/electriccommander/jre/bin/java -jar RTC_Console.jar fredJones topSecretPassword https://rtc.mydomain.com:9443/ccm/ DumpInfo 12

    If all is well, you should see output similar to this:
      RTC_Console Utility, version 2.1.0
      WorkItem: 12
      WorkitemType: defect
      ProjectArea: JKE Banking (Change Management)
      Category: BRM
      CurrentState: 1 (New)
      //Defined Types
      Type: defect (Defect)
      Type: task (Task)
      Type: com.ibm.team.apt.workItemType.story (Story)
      Type: com.ibm.team.apt.workItemType.epic (Epic)
      Type: com.ibm.team.workItemType.buildtrackingitem (Track Build Item)
      Type: com.ibm.team.workitem.workItemType.impediment (Impediment)
      Type: com.ibm.team.workItemType.adoption (Adoption Item)
      Type: com.ibm.team.workitem.workItemType.retrospective (Retrospective)
      //Defined Categories
      Category: JKE
      Category: BRM
      Category: Banking Logic
      Category: Build
      Category: C# UI
      Category: Database
      Category: EEM
      Category: Java UI
      Category: Mobile
      Category: Prerequisites
      Category: RelEng
      Category: Web UI
      //Defined States
      State: 2 (In Progress)
      State: 1 (New)
      State: 6 (Reopened)
      State: 3 (Resolved)
      State: 4 (Verified)
      //Defined Actions
      Action: com.ibm.team.workitem.defectWorkflow.action.resolve (Resolve)
      Action: com.ibm.team.workitem.defectWorkflow.action.startWorking (Start Workin
      Action: com.ibm.team.workitem.defectWorkflow.action.stopWorking (Stop Working)
      Action: com.ibm.team.workitem.defectWorkflow.action.verify (Verify)
      Action: com.ibm.team.workitem.defectWorkflow.action.confirm (Initialize)
      Action: com.ibm.team.workitem.defectWorkflow.action.setResolved (Set Resolved)
      Action: com.ibm.team.workitem.defectWorkflow.action.reopen (Reopen)
      //Defined Resolutions
      Resolution: 5 (Invalid)
      Resolution: 4 (Works for Me)
      Resolution: 3 (Works as Designed)
      Resolution: 2 (Duplicate)
      Resolution: 1 (Fixed)
      Resolution: 0 (Unresolved)
      Resolution: 8 (Fixed Upstream)
      //WorkItem Link Information
      //End
