permissionset 50000 "Projects Test GHP"
{
    Assignable = false;
    Caption = 'GitHub Projects - Test', MaxLength = 30;

    // Execute permission on the test framework only, so permission tests can lower the user's permissions
    // without losing access to the codeunits that run and check the test. It grants no table data.
    Permissions =
        codeunit "Library - Base URL GHP" = X,
        codeunit "Library - GitHub GHP" = X,
        codeunit "Mock Http Handler GHP" = X,
        codeunit "UT Base URL GHP" = X,
        codeunit "UT Base URL Token GHP" = X,
        codeunit "UT Base URL Perm. GHP" = X,
        codeunit "UT Env. Copy GHP" = X,
        codeunit "UT Base URL UI GHP" = X,
        codeunit "UT Owner GHP" = X,
        codeunit "UT Base URL Owners GHP" = X,
        codeunit "UT GitHub Requests GHP" = X,
        codeunit "UT Repository Update GHP" = X,
        codeunit "UT Update Errors GHP" = X,
        codeunit "UT Repository Perm. GHP" = X,
        codeunit "UT Repository UI GHP" = X,
        codeunit Assert = X,
        codeunit Any = X,
        codeunit "Permissions Mock" = X,
        codeunit "Library - Lower Permissions" = X;
}
