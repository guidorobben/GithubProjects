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
        MoreFailuresLbl: Label '...and %1 more.', Comment = '%1 = number of further failures';
        OwnerFailedLbl: Label '%1 %2: %3', Comment = '%1 = base URL code, %2 = owner name, %3 = error';
        OwnerNeedsGitHubErr: Label 'Owners can only be added to a base URL with Source Type GitHub. Base URL %1 is not a GitHub base URL.', Comment = '%1 = base URL code';
        OwnerRenameErr: Label 'An owner cannot be renamed. Delete the owner and create a new one.';
        RateLimitLbl: Label '%1: GitHub rate limit reached; %3 owner(s) skipped. The limit resets at %2.', Comment = '%1 = base URL code, %2 = date and time, %3 = number of owners';
        UpdatedMsg: Label 'The repositories of %1 owner(s) were updated.', Comment = '%1 = number of owners';
        UpdatedWithIgnoredMsg: Label 'The repositories of %1 owner(s) were updated. %2 owner(s) set to Ignore were skipped.', Comment = '%1 = number of updated owners, %2 = number of ignored owners';
        UpdateFailedErr: Label 'The repositories of %1 owner(s) could not be updated:\%2', Comment = '%1 = number of failed owners, %2 = list of failures';

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
        TempOwner: Record "Owner GHP" temporary;
        OwnerToUpdate: Record "Owner GHP";
        OwnerUpdate: Codeunit "Owner Update GHP";
        RateLimitResets: Dictionary of [Code[20], Text];
        SkippedOwners: Dictionary of [Code[20], Integer];
        Failures: List of [Text];
        BaseUrlCode: Code[20];
        ResetText: Text;
        FailedCount: Integer;
        IgnoredCount: Integer;
        UpdatedCount: Integer;
    begin
        IgnoredCount := CopyOwnersToUpdate(Owner, TempOwner);
        if TempOwner.FindSet() then
            repeat
                if RateLimitResets.ContainsKey(TempOwner."Base URL Code") then begin
                    SkippedOwners.Set(TempOwner."Base URL Code", SkippedOwners.Get(TempOwner."Base URL Code") + 1);
                    FailedCount += 1;
                end else begin
                    OwnerToUpdate := TempOwner;
                    // Each owner is a separate unit of work: Codeunit.Run commits it, and a failure rolls back only this owner.
                    Commit();
                    if OwnerUpdate.Run(OwnerToUpdate) then
                        UpdatedCount += 1
                    else begin
                        FailedCount += 1;
                        if OwnerUpdate.GetRateLimitReset(ResetText) then begin
                            RateLimitResets.Add(TempOwner."Base URL Code", ResetText);
                            SkippedOwners.Add(TempOwner."Base URL Code", 0);
                        end else
                            Failures.Add(StrSubstNo(OwnerFailedLbl, TempOwner."Base URL Code", TempOwner.Name, GetLastErrorText()));
                    end;
                end;
            until TempOwner.Next() = 0;

        foreach BaseUrlCode in RateLimitResets.Keys() do
            Failures.Add(StrSubstNo(RateLimitLbl, BaseUrlCode, RateLimitResets.Get(BaseUrlCode), SkippedOwners.Get(BaseUrlCode)));

        if Failures.Count() > 0 then
            Error(UpdateFailedErr, FailedCount, FormatFailures(Failures));

        if not GuiAllowed() then
            exit;
        if IgnoredCount > 0 then
            Message(UpdatedWithIgnoredMsg, UpdatedCount, IgnoredCount)
        else
            Message(UpdatedMsg, UpdatedCount);
    end;

    local procedure CopyOwnersToUpdate(var Owner: Record "Owner GHP"; var TempOwner: Record "Owner GHP" temporary) IgnoredCount: Integer
    begin
        if Owner.FindSet() then
            repeat
                // Owners set to Ignore are skipped without a request; their stored repositories are kept.
                if Owner."Repository Sync" <> Owner."Repository Sync"::Ignore then begin
                    TempOwner := Owner;
                    TempOwner.Insert(false);
                end else
                    IgnoredCount += 1;
            until Owner.Next() = 0;
    end;

    local procedure FormatFailures(Failures: List of [Text]): Text
    var
        FailureList: TextBuilder;
        Failure: Text;
        Listed: Integer;
        MaxListed: Integer;
    begin
        MaxListed := 10;
        Listed := 0;
        foreach Failure in Failures do
            if Listed < MaxListed then begin
                if Listed > 0 then
                    FailureList.AppendLine();
                FailureList.Append(Failure);
                Listed += 1;
            end;

        if Failures.Count() > MaxListed then begin
            FailureList.AppendLine();
            FailureList.Append(StrSubstNo(MoreFailuresLbl, Failures.Count() - MaxListed));
        end;
        exit(FailureList.ToText());
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
