codeunit 80002 "Owner Helper GHP"
{
    Access = Internal;
    Permissions =
        tabledata "Base URL GHP" = r,
        tabledata "Owner GHP" = r,
        tabledata "Repository GHP" = rd;

    var
        AllowedNameCharactersTok: Label 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_', Locked = true;
        DuplicateOwnerErr: Label 'Owner %1 already exists for base URL %2.', Comment = '%1 = owner name, %2 = base URL code';
        InvalidOwnerNameErr: Label 'The owner name %1 can only contain letters, digits, hyphens (-) and underscores (_).', Comment = '%1 = owner name';
        OwnerNeedsGitHubErr: Label 'Owners can only be added to a base URL with Source Type GitHub. Base URL %1 is not a GitHub base URL.', Comment = '%1 = base URL code';
        OwnerRenameErr: Label 'An owner cannot be renamed. Delete the owner and create a new one.';

    procedure CheckBaseUrl(var Owner: Record "Owner GHP")
    var
        BaseURL: Record "Base URL GHP";
    begin
        if Owner."Base URL Code" = '' then
            exit;

        BaseURL.SetLoadFields("Source Type");
        if not BaseURL.Get(Owner."Base URL Code") then
            Error(OwnerNeedsGitHubErr, Owner."Base URL Code");
        if BaseURL."Source Type" <> BaseURL."Source Type"::GitHub then
            Error(OwnerNeedsGitHubErr, Owner."Base URL Code");
    end;

    procedure ValidateName(var Owner: Record "Owner GHP")
    begin
        Owner.Name := CopyStr(DelChr(Owner.Name, '<>', ' '), 1, MaxStrLen(Owner.Name));
        if Owner.Name = '' then
            exit;

        CheckNameCharacters(Owner.Name);
        CheckDuplicate(Owner);
    end;

    procedure CheckOwner(var Owner: Record "Owner GHP")
    begin
        Owner.TestField("Base URL Code");
        CheckBaseUrl(Owner);
        Owner.TestField(Name);
        CheckNameCharacters(Owner.Name);
        CheckDuplicate(Owner);
    end;

    procedure RefuseRename()
    begin
        Error(OwnerRenameErr);
    end;

    procedure DeleteRepositories(var Owner: Record "Owner GHP")
    var
        Repository: Record "Repository GHP";
    begin
        Repository.SetRange("Base URL Code", Owner."Base URL Code");
        Repository.SetRange(Owner, Owner.Name);
        Repository.DeleteAll(true);
    end;

    procedure UpdateRepositories(var Owner: Record "Owner GHP")
    var
        UpdateRun: Codeunit "Update Run GHP";
    begin
        UpdateRun.UpdateOwners(Owner, false);
    end;

    procedure UpdateRepositoriesAndIssues(var Owner: Record "Owner GHP")
    var
        UpdateRun: Codeunit "Update Run GHP";
    begin
        UpdateRun.UpdateOwners(Owner, true);
    end;

    local procedure CheckNameCharacters(Name: Text)
    begin
        if DelChr(Name, '=', AllowedNameCharactersTok) <> '' then
            Error(InvalidOwnerNameErr, Name);
    end;

    local procedure CheckDuplicate(var Owner: Record "Owner GHP")
    var
        OtherOwner: Record "Owner GHP";
        LowerCaseName: Text;
    begin
        // A loop that skips the owner itself by SystemId: a name filter would follow the database collation, which may ignore case.
        LowerCaseName := LowerCase(Owner.Name);
        OtherOwner.SetRange("Base URL Code", Owner."Base URL Code");
        OtherOwner.SetLoadFields(Name);
        if OtherOwner.FindSet() then
            repeat
                if (OtherOwner.SystemId <> Owner.SystemId) and (LowerCase(OtherOwner.Name) = LowerCaseName) then
                    Error(DuplicateOwnerErr, Owner.Name, Owner."Base URL Code");
            until OtherOwner.Next() = 0;
    end;
}
