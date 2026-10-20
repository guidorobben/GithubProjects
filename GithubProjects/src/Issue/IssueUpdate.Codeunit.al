codeunit 80007 "Issue Update GHP"
{
    Access = Internal;
    Permissions =
        tabledata "Base URL GHP" = r,
        tabledata "Issue GHP" = rimd;
    TableNo = "Repository GHP";

    trigger OnRun()
    begin
        UpdateRepositoryIssues(Rec);
    end;

    var
        GitHubClient: Codeunit "GitHub Client GHP";
        ClosedTok: Label 'closed', Locked = true;
        IssuesLbl: Label '%1/repos/%2/%3/issues?state=all', Locked = true, Comment = '%1 = base URL, %2 = owner, %3 = repository name';
        OpenTok: Label 'open', Locked = true;
        UnknownStateErr: Label 'GitHub returned the unknown issue state %1.', Comment = '%1 = state';

    /// <summary>
    /// Returns whether the last update stopped on a GitHub rate limit, and when the limit resets.
    /// </summary>
    procedure GetRateLimitReset(var ResetText: Text): Boolean
    begin
        exit(GitHubClient.GetRateLimitReset(ResetText));
    end;

    local procedure UpdateRepositoryIssues(var Repository: Record "Repository GHP")
    var
        BaseURL: Record "Base URL GHP";
        TempIssue: Record "Issue GHP" temporary;
        Items: JsonArray;
    begin
        BaseURL.Get(Repository."Base URL Code");
        GitHubClient.Initialize(BaseURL);

        // Retrieve every page and read every item before the first write, so a failed request or an unknown state leaves the stored issues untouched.
        GitHubClient.GetAllPages(StrSubstNo(IssuesLbl, BaseURL.URL, Repository.Owner, Repository.Name), Items);
        ReadIssues(Repository, Items, TempIssue);

        UpsertIssues(TempIssue);
        DeleteIssuesNotReturned(Repository, TempIssue);
    end;

    local procedure ReadIssues(var Repository: Record "Repository GHP"; Items: JsonArray; var TempIssue: Record "Issue GHP" temporary)
    var
        ItemToken: JsonToken;
        ItemObject: JsonObject;
    begin
        foreach ItemToken in Items do begin
            ItemObject := ItemToken.AsObject();
            // GitHub's issue list also returns pull requests; they have a pull_request property and are not stored.
            if not ItemObject.Contains('pull_request') then begin
                TempIssue.Init();
                TempIssue."Base URL Code" := Repository."Base URL Code";
                TempIssue.Id := GetValue(ItemObject, 'id').AsBigInteger();
                TempIssue."Source Type" := TempIssue."Source Type"::GitHub;
                TempIssue."Repository Id" := Repository.Id;
                TempIssue.Number := GetValue(ItemObject, 'number').AsInteger();
                TempIssue.Type := TempIssue.Type::Issue;
                TempIssue.Description := CopyStr(GetValue(ItemObject, 'title').AsText(), 1, MaxStrLen(TempIssue.Description));
                TempIssue.State := MapState(GetValue(ItemObject, 'state').AsText());
                TempIssue.Insert(false);
            end;
        end;
    end;

    local procedure UpsertIssues(var TempIssue: Record "Issue GHP" temporary)
    var
        Issue: Record "Issue GHP";
    begin
        if TempIssue.FindSet() then
            repeat
                if Issue.Get(TempIssue."Base URL Code", TempIssue.Id) then begin
                    if (Issue."Repository Id" <> TempIssue."Repository Id") or (Issue.Number <> TempIssue.Number) or
                       (Issue.Description <> TempIssue.Description) or (Issue.State <> TempIssue.State)
                    then begin
                        Issue."Repository Id" := TempIssue."Repository Id";
                        Issue.Number := TempIssue.Number;
                        Issue.Description := TempIssue.Description;
                        Issue.State := TempIssue.State;
                        Issue.Modify(true);
                    end;
                end else begin
                    Issue := TempIssue;
                    Issue.Insert(true);
                end;
            until TempIssue.Next() = 0;
    end;

    local procedure DeleteIssuesNotReturned(var Repository: Record "Repository GHP"; var TempIssue: Record "Issue GHP" temporary)
    var
        Issue: Record "Issue GHP";
        IdsToDelete: List of [BigInteger];
        IssueId: BigInteger;
    begin
        Issue.SetRange("Base URL Code", Repository."Base URL Code");
        Issue.SetRange("Repository Id", Repository.Id);
        Issue.SetLoadFields(Id);
        if Issue.FindSet() then
            repeat
                if not TempIssue.Get(Issue."Base URL Code", Issue.Id) then
                    IdsToDelete.Add(Issue.Id);
            until Issue.Next() = 0;

        foreach IssueId in IdsToDelete do
            if Issue.Get(Repository."Base URL Code", IssueId) then
                Issue.Delete(true);
    end;

    local procedure MapState(State: Text): Enum "Issue State GHP"
    begin
        case State of
            OpenTok:
                exit(Enum::"Issue State GHP"::Open);
            ClosedTok:
                exit(Enum::"Issue State GHP"::Closed);
        end;
        Error(UnknownStateErr, State);
    end;

    local procedure GetValue(var JsonObject: JsonObject; PropertyName: Text): JsonValue
    var
        PropertyToken: JsonToken;
    begin
        JsonObject.Get(PropertyName, PropertyToken);
        exit(PropertyToken.AsValue());
    end;
}
