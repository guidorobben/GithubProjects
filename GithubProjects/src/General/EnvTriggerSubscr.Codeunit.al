codeunit 80001 "Env. Trigger Subscr. GHP"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Environment Triggers", OnAfterCopyEnvironmentPerCompany, '', false, false)]
    local procedure DeleteTokensOnAfterCopyEnvironmentPerCompany()
    var
        BaseURL: Record "Base URL GHP";
    begin
        BaseURL.DeleteAllTokens();
    end;
}
