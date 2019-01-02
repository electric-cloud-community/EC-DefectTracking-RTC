Building the RTC Client Program JAR
-----------------------------------

1) Aquire the correct RTC Client Java libraries.  As of this writing, that should
be version 4.0.2.  Extract the zip file into your build directory (which we'll
refer to as "x" from here on).  You should end up with a directory named
"RTC-Client-plainJavaLib-4.0.2" which will contain numerous jar files.  (See the
instructions in the README file in the "agent" directory for this plugin for
information on how and where to aquire the Rational RTC Client libraries.)

2) Ensure you have the correct JDK.  Ideally the version should match the version
of the JRE shipped with the oldest version of Commander supported by this
plugin.  Note also that the RTC Client Java libraries require a specific version
of the JDK.  As of the time of this writing, a good choice is 1.6.0_23.  Set
your JAVA_HOME environment variable to point to the appropriate JDK.

3) Create a subdirectory named "rtc_console" in your build directory, and copy
the RTC_Console.java source file into that subdirectory.

4) Copy the manifest.txt file to your build directory.  If you have changed the
version of the RTC Client Java libraries, you'll need to edit the manifest.txt
file and update it so that it contains the names of all of the jar files in the
"RTC-Client-plainJavaLib-x.y.z" directory.

5) Set your CLASSPATH to include all of the jar files in the RTC-Client-plainJavaLib
directory.  The easiest way to do this is to use a wildcard:
  export CLASSPATH='RTC-Client-plainJavaLib-4.0.2/*'

6) Compile the source:
  ${JAVA_HOME}/bin/javac rtc_console/RTC_Console.java

7) Assuming you encountered no errors, create the jar file from the compiled
classes and the manifest.txt file:
  ${JAVA_HOME}/bin/jar cfm RTC_Console.jar manifest.txt rtc_console/*.class

8) Copy your RTC_Console.jar file to the appropriate place (usually the "agent"
directory in the plugin).

