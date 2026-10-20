permissionset 80001 "Projects Admin GHP"
{
    Assignable = true;
    Caption = 'GitHub Projects - Admin', MaxLength = 30;
    IncludedPermissionSets = "Projects User GHP";

    Permissions =
        tabledata "Base URL GHP" = RIMD,
        tabledata "Owner GHP" = RIMD;
}
