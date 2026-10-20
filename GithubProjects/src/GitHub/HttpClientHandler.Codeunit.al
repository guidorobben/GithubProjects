codeunit 80005 "Http Client Handler GHP" implements "Http Client Handler"
{
    Access = Internal;

    /// <summary>
    /// Sends the request from this app, so "Allow HttpClient Requests" is set on GitHub Projects and not on the System Application.
    /// </summary>
    procedure Send(CurrHttpClientInstance: HttpClient; HttpRequestMessage: Codeunit "Http Request Message"; var HttpResponseMessage: Codeunit "Http Response Message") Success: Boolean
    var
        NativeHttpResponseMessage: HttpResponseMessage;
    begin
        Success := CurrHttpClientInstance.Send(HttpRequestMessage.GetHttpRequestMessage(), NativeHttpResponseMessage);
        HttpResponseMessage := HttpResponseMessage.Create(NativeHttpResponseMessage);
    end;
}
