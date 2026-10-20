codeunit 80006 "Repository Helper GHP"
{
    Access = Internal;
    Permissions =
        tabledata "Issue GHP" = rd,
        tabledata "Repository GHP" = r;

    var
        DeleteIssuesQst: Label 'Do you want to delete the stored issues of %1 repository(ies)?', Comment = '%1 = number of repositories';

    procedure DeleteIssues(var Repository: Record "Repository GHP")
    var
        Issue: Record "Issue GHP";
    begin
        Issue.SetRange("Base URL Code", Repository."Base URL Code");
        Issue.SetRange("Repository Id", Repository.Id);
        Issue.DeleteAll(true);
    end;

    procedure DeleteIssuesWithConfirmation(var Repository: Record "Repository GHP")
    var
        ConfirmManagement: Codeunit "Confirm Management";
    begin
        if Repository.IsEmpty() then
            exit;

        if not ConfirmManagement.GetResponseOrDefault(StrSubstNo(DeleteIssuesQst, Repository.Count()), false) then
            exit;

        if Repository.FindSet() then
            repeat
                DeleteIssues(Repository);
            until Repository.Next() = 0;
    end;

    procedure UpdateIssues(var Repository: Record "Repository GHP")
    var
        UpdateRun: Codeunit "Update Run GHP";
    begin
        UpdateRun.UpdateIssues(Repository);
    end;
}
