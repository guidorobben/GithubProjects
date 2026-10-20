permissionset 80000 "Projects User GHP"
{
    Assignable = true;
    Caption = 'GitHub Projects - User', MaxLength = 30;

    Permissions =
        table "Base URL GHP" = X,
        tabledata "Base URL GHP" = R,
        table "Owner GHP" = X,
        tabledata "Owner GHP" = R,
        table "Repository GHP" = X,
        tabledata "Repository GHP" = RiMD,
        table "Issue GHP" = X,
        tabledata "Issue GHP" = RimD,
        codeunit "Base URL Helper GHP" = X,
        codeunit "Env. Trigger Subscr. GHP" = X,
        codeunit "GitHub Client GHP" = X,
        codeunit "Http Client Handler GHP" = X,
        codeunit "Issue Update GHP" = X,
        codeunit "Owner Helper GHP" = X,
        codeunit "Owner Update GHP" = X,
        codeunit "Repository Helper GHP" = X,
        codeunit "Update Run GHP" = X,
        page "Base URLs GHP" = X,
        page "Issues GHP" = X,
        page "Owners GHP" = X,
        page "Repositories GHP" = X;
}
