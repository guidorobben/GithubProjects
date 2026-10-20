permissionset 80000 "Projects User GHP"
{
    Assignable = true;
    Caption = 'GitHub Projects - User', MaxLength = 30;

    Permissions =
        table "Base URL GHP" = X,
        tabledata "Base URL GHP" = R,
        codeunit "Base URL Helper GHP" = X,
        codeunit "Env. Trigger Subscr. GHP" = X,
        page "Base URLs GHP" = X;
}
