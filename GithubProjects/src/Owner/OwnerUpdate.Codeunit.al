codeunit 80003 "Owner Update GHP"
{
    Access = Internal;
    Permissions =
        tabledata "Base URL GHP" = r,
        tabledata "Repository GHP" = rimd;
    TableNo = "Owner GHP";

    trigger OnRun()
    begin
        UpdateOwner(Rec);
    end;

    var
        GitHubClient: Codeunit "GitHub Client GHP";
        TokenUserLogins: Dictionary of [Code[20], Text];
        OrganizationReposLbl: Label '%1/orgs/%2/repos', Locked = true, Comment = '%1 = base URL, %2 = owner name';
        TokenUserReposLbl: Label '%1/user/repos?affiliation=owner&visibility=all', Locked = true, Comment = '%1 = base URL';
        UserReposLbl: Label '%1/users/%2/repos', Locked = true, Comment = '%1 = base URL, %2 = owner name';

    /// <summary>
    /// Returns whether the last update stopped on a GitHub rate limit, and when the limit resets.
    /// </summary>
    procedure GetRateLimitReset(var ResetText: Text): Boolean
    begin
        exit(GitHubClient.GetRateLimitReset(ResetText));
    end;

    local procedure UpdateOwner(var Owner: Record "Owner GHP")
    var
        BaseURL: Record "Base URL GHP";
        Repositories: JsonArray;
        SeenIds: Dictionary of [Code[50], Boolean];
    begin
        BaseURL.Get(Owner."Base URL Code");
        GitHubClient.Initialize(BaseURL);

        // Retrieve every page before the first write, so a failed request leaves the stored repositories untouched.
        GitHubClient.GetAllPages(GetRepositoriesUrl(BaseURL, Owner), Repositories);

        UpsertRepositories(Owner, Repositories, SeenIds);
        DeleteRepositoriesNotReturned(Owner, SeenIds);
    end;

    local procedure GetRepositoriesUrl(var BaseURL: Record "Base URL GHP"; var Owner: Record "Owner GHP"): Text
    begin
        case Owner."Owner Type" of
            Owner."Owner Type"::Organization:
                exit(StrSubstNo(OrganizationReposLbl, BaseURL.URL, Owner.Name));
            Owner."Owner Type"::User:
                if IsTokenUser(BaseURL, Owner) then
                    exit(StrSubstNo(TokenUserReposLbl, BaseURL.URL))
                else
                    exit(StrSubstNo(UserReposLbl, BaseURL.URL, Owner.Name));
        end;
    end;

    local procedure IsTokenUser(var BaseURL: Record "Base URL GHP"; var Owner: Record "Owner GHP"): Boolean
    var
        Login: Text;
    begin
        if not BaseURL.HasToken() then
            exit(false);

        if not TokenUserLogins.Get(BaseURL.Code, Login) then begin
            Login := GitHubClient.GetTokenUserLogin();
            TokenUserLogins.Add(BaseURL.Code, Login);
        end;
        exit(LowerCase(Login) = LowerCase(Owner.Name));
    end;

    local procedure UpsertRepositories(var Owner: Record "Owner GHP"; Repositories: JsonArray; var SeenIds: Dictionary of [Code[50], Boolean])
    var
        Repository: Record "Repository GHP";
        RepositoryToken: JsonToken;
        RepositoryObject: JsonObject;
        RepositoryId: Code[50];
        RepositoryName: Text[100];
        IssuesEnabled: Boolean;
    begin
        foreach RepositoryToken in Repositories do begin
            RepositoryObject := RepositoryToken.AsObject();
            RepositoryId := CopyStr(Format(GetValue(RepositoryObject, 'id').AsBigInteger(), 0, 9), 1, MaxStrLen(RepositoryId));
            RepositoryName := CopyStr(GetValue(RepositoryObject, 'name').AsText(), 1, MaxStrLen(RepositoryName));
            IssuesEnabled := GetIssuesEnabled(RepositoryObject);
            if not SeenIds.ContainsKey(RepositoryId) then
                SeenIds.Add(RepositoryId, true);

            if Repository.Get(Owner."Base URL Code", RepositoryId) then begin
                // Issue Sync is the user's choice and is never changed by an update.
                if (Repository.Owner <> Owner.Name) or (Repository.Name <> RepositoryName) or (Repository."Issues Enabled" <> IssuesEnabled) then begin
                    Repository.Owner := Owner.Name;
                    Repository.Name := RepositoryName;
                    Repository."Issues Enabled" := IssuesEnabled;
                    Repository.Modify(true);
                end;
            end else begin
                Repository.Init();
                Repository."Base URL Code" := Owner."Base URL Code";
                Repository.Id := RepositoryId;
                Repository."Source Type" := Repository."Source Type"::GitHub;
                Repository.Owner := Owner.Name;
                Repository.Name := RepositoryName;
                Repository."Issues Enabled" := IssuesEnabled;
                Repository.Insert(true);
            end;
        end;
    end;

    local procedure DeleteRepositoriesNotReturned(var Owner: Record "Owner GHP"; var SeenIds: Dictionary of [Code[50], Boolean])
    var
        Repository: Record "Repository GHP";
        IdsToDelete: List of [Code[50]];
        RepositoryId: Code[50];
    begin
        Repository.SetRange("Base URL Code", Owner."Base URL Code");
        Repository.SetRange(Owner, Owner.Name);
        Repository.SetLoadFields(Id);
        if Repository.FindSet() then
            repeat
                if not SeenIds.ContainsKey(Repository.Id) then
                    IdsToDelete.Add(Repository.Id);
            until Repository.Next() = 0;

        foreach RepositoryId in IdsToDelete do
            if Repository.Get(Owner."Base URL Code", RepositoryId) then
                Repository.Delete(true);
    end;

    local procedure GetValue(var JsonObject: JsonObject; PropertyName: Text): JsonValue
    var
        PropertyToken: JsonToken;
    begin
        JsonObject.Get(PropertyName, PropertyToken);
        exit(PropertyToken.AsValue());
    end;

    local procedure GetIssuesEnabled(var RepositoryObject: JsonObject): Boolean
    var
        PropertyToken: JsonToken;
    begin
        // has_issues is optional in GitHub's minimal repository schema; issues are on by default in GitHub.
        if not RepositoryObject.Get('has_issues', PropertyToken) then
            exit(true);
        if PropertyToken.AsValue().IsNull() then
            exit(true);
        exit(PropertyToken.AsValue().AsBoolean());
    end;
}
