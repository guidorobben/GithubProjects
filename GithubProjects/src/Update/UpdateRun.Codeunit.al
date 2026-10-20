codeunit 80008 "Update Run GHP"
{
    Access = Internal;
    Permissions =
        tabledata "Owner GHP" = r,
        tabledata "Repository GHP" = r;

    var
        OwnerUpdate: Codeunit "Owner Update GHP";
        IssueUpdate: Codeunit "Issue Update GHP";
        RateLimitResets: Dictionary of [Code[20], Text];
        SkippedOwnersByBaseUrl: Dictionary of [Code[20], Integer];
        SkippedRepositoriesByBaseUrl: Dictionary of [Code[20], Integer];
        Failures: List of [Text];
        FailedCount: Integer;
        IgnoredOwners: Integer;
        SkippedNotGitHub: Integer;
        SkippedIssuesDisabled: Integer;
        SkippedIssueSyncIgnore: Integer;
        SkippedOwnerIgnore: Integer;
        UpdatedOwners: Integer;
        UpdatedRepositories: Integer;
        IssuesUpdatedMsg: Label 'The issues of %1 repository(ies) were updated. %2 repository(ies) were skipped.', Comment = '%1 = number of updated repositories, %2 = number of skipped repositories';
        IssuesUpdatedWithReasonsMsg: Label 'The issues of %1 repository(ies) were updated. %2 repository(ies) were skipped: %3 with Issue Sync set to Ignore, %4 with Issues Enabled set to No (Update Repositories refreshes this), %5 of an owner with Repository Sync set to Ignore.', Comment = '%1 = number of updated repositories, %2 = number of skipped repositories, %3/%4/%5 = number skipped for each reason';
        MoreFailuresLbl: Label '...and %1 more.', Comment = '%1 = number of further failures';
        OwnerFailedLbl: Label '%1 %2: %3', Comment = '%1 = base URL code, %2 = owner name, %3 = error';
        RateLimitLbl: Label '%1: GitHub rate limit reached; %3 owner(s) and %4 repository(ies) skipped. The limit resets at %2.', Comment = '%1 = base URL code, %2 = date and time, %3 = number of owners, %4 = number of repositories';
        RepositoriesAndIssuesUpdatedMsg: Label 'The repositories of %1 owner(s) and the issues of %2 repository(ies) were updated. %3 owner(s) and %4 repository(ies) were skipped.', Comment = '%1 = number of updated owners, %2 = number of updated repositories, %3 = number of skipped owners, %4 = number of skipped repositories';
        RepositoriesAndIssuesWithReasonsMsg: Label 'The repositories of %1 owner(s) and the issues of %2 repository(ies) were updated. %3 owner(s) and %4 repository(ies) were skipped. Repositories skipped: %5 with Issue Sync set to Ignore, %6 with Issues Enabled set to No.', Comment = '%1 = number of updated owners, %2 = number of updated repositories, %3 = number of skipped owners, %4 = number of skipped repositories, %5/%6 = number skipped for each reason';
        RepositoryFailedLbl: Label '%1 %2/%3: %4', Comment = '%1 = base URL code, %2 = owner, %3 = repository name, %4 = error';
        UpdatedMsg: Label 'The repositories of %1 owner(s) were updated.', Comment = '%1 = number of owners';
        UpdatedWithIgnoredMsg: Label 'The repositories of %1 owner(s) were updated. %2 owner(s) set to Ignore were skipped.', Comment = '%1 = number of updated owners, %2 = number of ignored owners';
        UpdateFailedErr: Label 'The update failed for %1 owner(s) or repository(ies):\%2', Comment = '%1 = number of failed owners and repositories, %2 = list of failures';

    /// <summary>
    /// Updates the repositories of the owners in the filter and, when WithIssues is set, the issues of their eligible repositories.
    /// </summary>
    procedure UpdateOwners(var Owner: Record "Owner GHP"; WithIssues: Boolean)
    var
        TempOwner: Record "Owner GHP" temporary;
    begin
        CopyOwnersToUpdate(Owner, TempOwner);
        if TempOwner.FindSet() then
            repeat
                if RunOwnerUpdate(TempOwner) and WithIssues then
                    UpdateIssuesOfOwner(TempOwner);
            until TempOwner.Next() = 0;

        Finish(true, WithIssues);
    end;

    /// <summary>
    /// Updates the issues of the eligible repositories in the filter.
    /// </summary>
    procedure UpdateIssues(var Repository: Record "Repository GHP")
    var
        TempRepository: Record "Repository GHP" temporary;
    begin
        CopyRepositories(Repository, TempRepository);
        if TempRepository.FindSet() then
            repeat
                RunIssueUpdateIfEligible(TempRepository);
            until TempRepository.Next() = 0;

        Finish(false, true);
    end;

    local procedure RunOwnerUpdate(var TempOwner: Record "Owner GHP" temporary): Boolean
    var
        OwnerToUpdate: Record "Owner GHP";
        ResetText: Text;
    begin
        if RateLimitResets.ContainsKey(TempOwner."Base URL Code") then begin
            AddSkipped(SkippedOwnersByBaseUrl, TempOwner."Base URL Code");
            exit(false);
        end;

        OwnerToUpdate := TempOwner;
        // Each owner is a separate unit of work: Codeunit.Run commits it, and a failure rolls back only this owner.
        Commit();
        if OwnerUpdate.Run(OwnerToUpdate) then begin
            UpdatedOwners += 1;
            exit(true);
        end;

        FailedCount += 1;
        if OwnerUpdate.GetRateLimitReset(ResetText) then
            RegisterRateLimit(TempOwner."Base URL Code", ResetText)
        else
            Failures.Add(StrSubstNo(OwnerFailedLbl, TempOwner."Base URL Code", TempOwner.Name, GetLastErrorText()));
        exit(false);
    end;

    local procedure UpdateIssuesOfOwner(var TempOwner: Record "Owner GHP" temporary)
    var
        Repository: Record "Repository GHP";
        TempRepository: Record "Repository GHP" temporary;
    begin
        Repository.SetRange("Base URL Code", TempOwner."Base URL Code");
        Repository.SetRange(Owner, TempOwner.Name);
        CopyRepositories(Repository, TempRepository);
        if TempRepository.FindSet() then
            repeat
                RunIssueUpdateIfEligible(TempRepository);
            until TempRepository.Next() = 0;
    end;

    local procedure RunIssueUpdateIfEligible(var TempRepository: Record "Repository GHP" temporary)
    var
        RepositoryToUpdate: Record "Repository GHP";
        ResetText: Text;
    begin
        if IsSkipped(TempRepository) then
            exit;

        if RateLimitResets.ContainsKey(TempRepository."Base URL Code") then begin
            AddSkipped(SkippedRepositoriesByBaseUrl, TempRepository."Base URL Code");
            exit;
        end;

        RepositoryToUpdate := TempRepository;
        // Each repository is a separate unit of work, as each owner is.
        Commit();
        if IssueUpdate.Run(RepositoryToUpdate) then begin
            UpdatedRepositories += 1;
            exit;
        end;

        FailedCount += 1;
        if IssueUpdate.GetRateLimitReset(ResetText) then
            RegisterRateLimit(TempRepository."Base URL Code", ResetText)
        else
            Failures.Add(StrSubstNo(RepositoryFailedLbl, TempRepository."Base URL Code", TempRepository.Owner, TempRepository.Name, GetLastErrorText()));
    end;

    local procedure IsSkipped(var TempRepository: Record "Repository GHP" temporary): Boolean
    var
        Owner: Record "Owner GHP";
    begin
        // Counts the reason, so the closing message can tell the user why repositories were skipped.
        if TempRepository."Source Type" <> TempRepository."Source Type"::GitHub then
            exit(CountSkipped(SkippedNotGitHub));
        // Issue Sync is extensible: values added by other apps behave like Include.
        if TempRepository."Issue Sync" = TempRepository."Issue Sync"::Ignore then
            exit(CountSkipped(SkippedIssueSyncIgnore));
        if not TempRepository."Issues Enabled" then
            exit(CountSkipped(SkippedIssuesDisabled));

        Owner.SetLoadFields("Repository Sync");
        if Owner.Get(TempRepository."Base URL Code", TempRepository.Owner) then
            if Owner."Repository Sync" = Owner."Repository Sync"::Ignore then
                exit(CountSkipped(SkippedOwnerIgnore));
        exit(false);
    end;

    local procedure CountSkipped(var SkippedForReason: Integer): Boolean
    begin
        SkippedForReason += 1;
        exit(true);
    end;

    local procedure CopyOwnersToUpdate(var Owner: Record "Owner GHP"; var TempOwner: Record "Owner GHP" temporary)
    begin
        if Owner.FindSet() then
            repeat
                // Owners set to Ignore are skipped without a request; their stored repositories are kept.
                if Owner."Repository Sync" <> Owner."Repository Sync"::Ignore then begin
                    TempOwner := Owner;
                    TempOwner.Insert(false);
                end else
                    IgnoredOwners += 1;
            until Owner.Next() = 0;
    end;

    local procedure CopyRepositories(var Repository: Record "Repository GHP"; var TempRepository: Record "Repository GHP" temporary)
    begin
        if Repository.FindSet() then
            repeat
                TempRepository := Repository;
                TempRepository.Insert(false);
            until Repository.Next() = 0;
    end;

    local procedure RegisterRateLimit(BaseUrlCode: Code[20]; ResetText: Text)
    begin
        RateLimitResets.Set(BaseUrlCode, ResetText);
    end;

    local procedure AddSkipped(var SkippedByBaseUrl: Dictionary of [Code[20], Integer]; BaseUrlCode: Code[20])
    begin
        FailedCount += 1;
        SkippedByBaseUrl.Set(BaseUrlCode, GetSkipped(SkippedByBaseUrl, BaseUrlCode) + 1);
    end;

    local procedure GetSkipped(var SkippedByBaseUrl: Dictionary of [Code[20], Integer]; BaseUrlCode: Code[20]): Integer
    begin
        if SkippedByBaseUrl.ContainsKey(BaseUrlCode) then
            exit(SkippedByBaseUrl.Get(BaseUrlCode));
        exit(0);
    end;

    local procedure Finish(WithOwners: Boolean; WithIssues: Boolean)
    var
        BaseUrlCode: Code[20];
        SkippedRepositories: Integer;
    begin
        SkippedRepositories := SkippedNotGitHub + SkippedIssueSyncIgnore + SkippedIssuesDisabled + SkippedOwnerIgnore;
        foreach BaseUrlCode in RateLimitResets.Keys() do
            Failures.Add(StrSubstNo(RateLimitLbl, BaseUrlCode, RateLimitResets.Get(BaseUrlCode),
                GetSkipped(SkippedOwnersByBaseUrl, BaseUrlCode), GetSkipped(SkippedRepositoriesByBaseUrl, BaseUrlCode)));

        if Failures.Count() > 0 then
            Error(UpdateFailedErr, FailedCount, FormatFailures(Failures));

        if not GuiAllowed() then
            exit;

        if WithOwners and WithIssues then begin
            if SkippedRepositories > 0 then
                Message(RepositoriesAndIssuesWithReasonsMsg, UpdatedOwners, UpdatedRepositories, IgnoredOwners, SkippedRepositories, SkippedIssueSyncIgnore, SkippedIssuesDisabled)
            else
                Message(RepositoriesAndIssuesUpdatedMsg, UpdatedOwners, UpdatedRepositories, IgnoredOwners, SkippedRepositories);
        end else
            if WithOwners then begin
                if IgnoredOwners > 0 then
                    Message(UpdatedWithIgnoredMsg, UpdatedOwners, IgnoredOwners)
                else
                    Message(UpdatedMsg, UpdatedOwners);
            end else
                if SkippedRepositories > 0 then
                    Message(IssuesUpdatedWithReasonsMsg, UpdatedRepositories, SkippedRepositories, SkippedIssueSyncIgnore, SkippedIssuesDisabled, SkippedOwnerIgnore)
                else
                    Message(IssuesUpdatedMsg, UpdatedRepositories, SkippedRepositories);
    end;

    local procedure FormatFailures(FailureLines: List of [Text]): Text
    var
        FailureList: TextBuilder;
        Failure: Text;
        Listed: Integer;
        MaxListed: Integer;
    begin
        MaxListed := 10;
        Listed := 0;
        foreach Failure in FailureLines do
            if Listed < MaxListed then begin
                if Listed > 0 then
                    FailureList.AppendLine();
                FailureList.Append(Failure);
                Listed += 1;
            end;

        if FailureLines.Count() > MaxListed then begin
            FailureList.AppendLine();
            FailureList.Append(StrSubstNo(MoreFailuresLbl, FailureLines.Count() - MaxListed));
        end;
        exit(FailureList.ToText());
    end;
}
