codeunit 50010 "UT Update Errors GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        LastMessage: Text;
        MoreFailuresLbl: Label '...and %1 more.', Comment = '%1 = number of further failures';
        OwnerFailedLbl: Label '%1 %2: %3', Comment = '%1 = base URL code, %2 = owner name, %3 = error';
        RateLimitLbl: Label '%1: GitHub rate limit reached; %3 owner(s) skipped. The limit resets at %2.', Comment = '%1 = base URL code, %2 = date and time, %3 = number of owners';
        RequestFailedErr: Label 'The request to %1 failed with status %2 %3.', Comment = '%1 = URL, %2 = HTTP status code, %3 = reason phrase';
        UpdatedMsg: Label 'The repositories of %1 owner(s) were updated.', Comment = '%1 = number of owners';
        UpdatedWithIgnoredMsg: Label 'The repositories of %1 owner(s) were updated. %2 owner(s) set to Ignore were skipped.', Comment = '%1 = number of updated owners, %2 = number of ignored owners';
        RepositoryNameKeptTok: Label 'The stored repository of an ignored owner must be kept unchanged.', Locked = true;
        RepositoryMustExistTok: Label 'The repository must exist.', Locked = true;
        UnexpectedRequestCountTok: Label 'Unexpected number of requests.', Locked = true;
        UnexpectedMessageTok: Label 'Unexpected message.', Locked = true;
        UnexpectedErrorTok: Label 'The error must not mention %1.', Locked = true, Comment = '%1 = text';

    [Test]
    procedure E1_FailureOfOneOwnerDoesNotStopOthers()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO E1] One failing owner does not stop the others; the run ends with an error that names it.
        // [GIVEN] GH1 with ORG (404) and USR (R2)
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 404, 'Not Found', '', '');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated in one run
        Owner.SetRange("Base URL Code", BaseURL.Code);
        asserterror Owner.UpdateRepositories();

        // [THEN] 102 exists for USR; the error names GH1, org-a and the 404
        Assert.ExpectedError(StrSubstNo(OwnerFailedLbl, BaseURL.Code, 'org-a', StrSubstNo(RequestFailedErr, LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 404, 'Not Found')));
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '102'), RepositoryMustExistTok);
    end;

    [Test]
    procedure E2_RateLimitSkipsRestOfBaseUrl()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        TypeHelper: Codeunit "Type Helper";
        ResetEpoch: BigInteger;
    begin
        // [SCENARIO E2] A rate limit skips the other owners of that base URL; other base URLs are still updated.
        // [GIVEN] GH1 with ORG (rate limited) and USR; GH2 with OTHER (R3)
        ResetEpoch := 1798761600;
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-c');
        MockHttpHandlerGHP.AddRateLimitResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 403, ResetEpoch, 0);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(OtherBaseURL, 'org-c'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R3()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] All three are updated in one run
        Owner.SetFilter("Base URL Code", '%1|%2', BaseURL.Code, OtherBaseURL.Code);
        asserterror Owner.UpdateRepositories();

        // [THEN] No request for USR; 103 exists; one rate-limit line for GH1 with 1 skipped owner
        Assert.ExpectedError(StrSubstNo(RateLimitLbl, BaseURL.Code, Format(TypeHelper.EvaluateUnixTimestamp(ResetEpoch)), 1));
        Assert.AreEqual(2, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(OtherBaseURL.Code, '103'), RepositoryMustExistTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    procedure E3_RetryAfterIsARateLimit()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO E3] A 429 response with retry-after is a rate limit.
        // [GIVEN] GH1 with ORG (429, retry-after 60) and USR
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddRateLimitResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 429, 0, 60);
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated
        Owner.SetRange("Base URL Code", BaseURL.Code);
        asserterror Owner.UpdateRepositories();

        // [THEN] No request for USR; the error has the rate-limit line for GH1
        Assert.ExpectedError(RateLimitLinePrefix(BaseURL.Code, 1));
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
    end;

    [Test]
    procedure E4_PlainForbiddenIsOrdinaryFailure()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO E4] A 403 without rate-limit headers fails only that owner.
        // [GIVEN] GH1 with ORG (403) and USR (R2)
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 403, 'Forbidden', '', '');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated
        Owner.SetRange("Base URL Code", BaseURL.Code);
        asserterror Owner.UpdateRepositories();

        // [THEN] USR was requested and 102 exists; the error names ORG with 403
        Assert.ExpectedError(StrSubstNo(RequestFailedErr, LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 403, 'Forbidden'));
        Assert.AreEqual(2, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '102'), RepositoryMustExistTok);
    end;

    [Test]
    procedure E5_ConnectionFailureIsCollected()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO E5] A request without a response fails only that owner.
        // [GIVEN] GH1 with ORG (no response) and USR (R2)
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddConnectionFailure(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated
        Owner.SetRange("Base URL Code", BaseURL.Code);
        asserterror Owner.UpdateRepositories();

        // [THEN] 102 exists; the error names ORG
        Assert.ExpectedError(StrSubstNo(OwnerFailedLbl, BaseURL.Code, 'org-a', ''));
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '102'), RepositoryMustExistTok);
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure E6_SuccessShowsMessage()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO E6] When all owners are updated, a message says how many.
        // [GIVEN] GH1 with ORG and USR, a page for each
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated
        Owner.SetRange("Base URL Code", BaseURL.Code);
        Owner.UpdateRepositories();

        // [THEN] The message with 2
        Assert.AreEqual(StrSubstNo(UpdatedMsg, 2), LastMessage, UnexpectedMessageTok);
    end;

    [Test]
    procedure E7_AtMostTenFailuresAreListed()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        OwnerName: Text[100];
        Index: Integer;
    begin
        // [SCENARIO E7] The error lists at most 10 failures, followed by the number of further failures.
        // [GIVEN] 12 owners on GH1, each 404
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        for Index := 1 to 12 do begin
            OwnerName := CopyStr('org-' + Format(Index + 10), 1, 100);
            LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, OwnerName);
            MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, OwnerName), 404, 'Not Found', '', '');
        end;
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] All are updated
        Owner.SetRange("Base URL Code", BaseURL.Code);
        asserterror Owner.UpdateRepositories();

        // [THEN] 10 failures (org-11 to org-20) and "...and 2 more."
        Assert.ExpectedError(StrSubstNo(MoreFailuresLbl, 2));
        Assert.ExpectedError(StrSubstNo(OwnerFailedLbl, BaseURL.Code, 'org-20', ''));
        Assert.AreEqual(0, StrPos(GetLastErrorText(), 'org-21'), StrSubstNo(UnexpectedErrorTok, 'org-21'));
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure E8_IgnoredOwnerIsSkipped()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO E8] An owner set to Ignore gets no request and keeps its stored repositories.
        // [GIVEN] GH1 with ORG (Ignore, 101 stored as old-name) and USR (R2)
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        Owner.Validate("Repository Sync", Owner."Repository Sync"::Ignore);
        Owner.Modify(true);
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'old-name');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated in one run
        Owner.SetRange("Base URL Code", BaseURL.Code);
        Owner.UpdateRepositories();

        // [THEN] Only USR is requested; 101 is unchanged; the message counts 1 updated and 1 ignored owner
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Repository.SetLoadFields(Name);
        Repository.Get(BaseURL.Code, '101');
        Assert.AreEqual('old-name', Repository.Name, RepositoryNameKeptTok);
        Assert.AreEqual(StrSubstNo(UpdatedWithIgnoredMsg, 1, 1), LastMessage, UnexpectedMessageTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure E9_OnlyIgnoredOwnersSendNoRequest()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO E9] Updating only owners set to Ignore sends no request and says so.
        // [GIVEN] GH1 with ORG set to Ignore
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        Owner.Validate("Repository Sync", Owner."Repository Sync"::Ignore);
        Owner.Modify(true);
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        Owner.SetRecFilter();
        Owner.UpdateRepositories();

        // [THEN] No request; the message counts 0 updated and 1 ignored owner
        Assert.AreEqual(0, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(StrSubstNo(UpdatedWithIgnoredMsg, 0, 1), LastMessage, UnexpectedMessageTok);
    end;
    local procedure RateLimitLinePrefix(BaseUrlCode: Code[20]; SkippedOwners: Integer): Text
    var
        RateLimitLine: Text;
    begin
        RateLimitLine := StrSubstNo(RateLimitLbl, BaseUrlCode, '#', SkippedOwners);
        exit(CopyStr(RateLimitLine, 1, StrPos(RateLimitLine, '#') - 1));
    end;

    [MessageHandler]
    procedure StoreMessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;
}
