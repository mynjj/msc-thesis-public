enum AppTestCategories {
    other
    al_tr
    cal_tr
    unknown
}

$global:UNKNOWN_APPTESTCATEGORY = [AppTestCategories]::unknown

$global:AppTestTasksCategories = @{
    'TestFinancialsBacpacsW1' = [AppTestCategories]::other;
    'RunBVT' = [AppTestCategories]::other;
    'VerifyApplicationChanges' = [AppTestCategories]::other;

    'RunALTestDevTools' = [AppTestCategories]::cal_tr;
    'RunALTests_{}_DemoData' = [AppTestCategories]::cal_tr;
    'RunALTests_{}_Bucket{}' = [AppTestCategories]::cal_tr;
    'RunALTests_{}_O365Bucket{}' = [AppTestCategories]::cal_tr;
    'RunALTests_{}_Permissions' = [AppTestCategories]::cal_tr;
    'RunALTests_{}_OnPremBucket{}' = [AppTestCategories]::cal_tr;
    'RunALTests_W1_Bucket{}' = [AppTestCategories]::cal_tr;
    'RunALTests_W1_CostingSuite' = [AppTestCategories]::cal_tr;
    'RunALTests_W1_DemoData' = [AppTestCategories]::cal_tr;
    'RunALTests_W1_MockServiceTests' = [AppTestCategories]::cal_tr;

    'RunALTestSystemModules_Group{}' = [AppTestCategories]::al_tr;
    'RunConversionUpgrade{}_W1' = [AppTestCategories]::al_tr;
    'RunALTests_{}_WebServices' = [AppTestCategories]::al_tr;
    'RunALTests_{}_UserBasedWebServices' = [AppTestCategories]::al_tr;
    'RunALTests_{}_Extensions' = [AppTestCategories]::al_tr;
    'RunALTests_{}_ExtensionsWebServices' = [AppTestCategories]::al_tr;
    'RunALTests_W1_WebServices' = [AppTestCategories]::al_tr;
    'RunALTests_W1_UserBasedWebServices' = [AppTestCategories]::al_tr;
    'RunALTests_W1_Extensions' = [AppTestCategories]::al_tr;
    'RunALTests_W1_ExtensionsWebServices' = [AppTestCategories]::al_tr;
    'RunALTests_{}_UpgradeTestOnNewDatabase' = [AppTestCategories]::al_tr;
    'RunALTests_W1_UpgradeTestOnNewDatabase' = [AppTestCategories]::al_tr;
}