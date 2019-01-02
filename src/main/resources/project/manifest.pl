@files = (
    ['//property[propertyName="ECDefectTracking::RTC::Cfg"]/value', 'RTCCfg.pm'],
    ['//property[propertyName="ECDefectTracking::RTC::Driver"]/value', 'RTCDriver.pm'],
    ['//property[propertyName="createConfig"]/value', 'rtcCreateConfigForm.xml'],
    ['//property[propertyName="editConfig"]/value', 'rtcEditConfigForm.xml'],
    ['//property[propertyName="ec_setup"]/value', 'ec_setup.pl'],
	['//procedure[procedureName="LinkDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-LinkDefects.xml'],	
	['//procedure[procedureName="UpdateDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-UpdateDefects.xml'],	
	['//procedure[procedureName="CreateDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-CreateDefects.xml'],	
);
