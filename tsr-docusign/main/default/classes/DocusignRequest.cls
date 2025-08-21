public with sharing class DocusignRequest {
	static final String DOCUSIGN_ERROR_CODE = 'errorCode';
	static final String DOCUSIGN_MESSAGE = 'message';
	static final String CONTENT_TYPE_TEXT = 'Content-Type';
	static final String APPLICATION_JSON_TEXT = 'application/json';
	static final String DOCUSIGN_AUTHORIZATION_HEADER = 'Authorization';
	static final Integer SUCCESS_200_CODE = 200;
	static final Integer SUCCESS_201_CODE = 201;
	@TestVisible
	static final String DESERIALIZE_JSON_ERROR = Label.Deserialize_JSON_Error;
	@TestVisible
	private HttpRequest request;
	private Http http;
	private HttpResponse response;
	private Map<String, Object> responseBodyMap;
	private Boolean deserializeJSON;
	@TestVisible
	private String path;
	@TestVisible
	private DocusignOAuth oAuth;
	
	public static HttpRequest buildRequest(String methodType){
		HttpRequest request = new HttpRequest();
        request.setTimeout(new DocusignOptions().timeout);
        request.setMethod(methodType);
        request.setHeader(CONTENT_TYPE_TEXT, APPLICATION_JSON_TEXT);
        return request;  
	}

	public DocusignRequest(String method, String path){
		this(method, path, true);
	}
	public DocusignRequest(String method, String path, Boolean deserializeJSON){
		this(buildRequest(method), deserializeJSON, null);
		this.path = path;
	}
	public DocusignRequest(HttpRequest request){
		this(request, true, null);
	}
	public DocusignRequest(HttpRequest request, Boolean deserializeJSON, DocusignOAuth oAuth){
		this.deserializeJSON = deserializeJSON;
		http = new Http();
		this.request = request;
		this.oAuth = oAuth == null ? new DocusignOAuth() : oAuth;
		setOAuthHeader();
	}
	public DocusignRequest but(String method, String path){
		return this.but(method, path, true);
	}
	/**
	 * but method is to create another DocusignRequest instance to reuse the existing OAuth infomartion
	 */
	public DocusignRequest but(String method, String path, Boolean deserializeJSON){
		HttpRequest request = buildRequest(method);
		DocusignRequest dr = new DocusignRequest(request, deserializeJSON, this.oAuth);
		dr.path = path;
		return dr;
	}
	public void setOAuthHeader(){
		this.request.setHeader(DOCUSIGN_AUTHORIZATION_HEADER, 'Bearer ' + this.oAuth.getAccessToken());
	}
	public DocusignRequest withBody(String body){
		request.setBody(body);
		return this;
	}
	public DocusignRequest withEndpoint(String endpoint){
		request.setEndpoint(endpoint);
		return this;
	}
	public DocusignRequest execute(){
		if(String.isBlank(request.getEndpoint())){
			request.setEndpoint(oAuth.getBaseUri() + path);
		}
		response = http.send(request);
		if(deserializeJSON){
			try {
				responseBodyMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());	
			} catch (JSONException e) {
				throw new DocuSignException(DESERIALIZE_JSON_ERROR);
			}
		}
		if(response.getStatusCode() != SUCCESS_200_CODE && response.getStatusCode() != SUCCESS_201_CODE){
			String errorCode = String.valueOf(responseBodyMap.get(DOCUSIGN_ERROR_CODE));
			String errorMessage = String.valueOf(responseBodyMap.get(DOCUSIGN_MESSAGE));
			// if access token is not valid, try to re-obtain it
			// question: maybe limit of times for obtaining access token attempts?
			if(DocusignOAuth.isUserAuthenticationFailed(errorCode)){
				return refreshAccessTokenAndExecute();
			}
			throw new DocuSignException(errorCode + ' ' + errorMessage);
		}
		return this;
	}
	public DocusignRequest refreshAccessTokenAndExecute(){
		oAuth.obtainAccessToken();
		setOAuthHeader();
		return execute();
	}
	public void upsertAccessTokenSetting(){
		oAuth.upsertAccessTokenSetting();
	}
	public Map<String, Object> getResponseBodyMap(){
		return responseBodyMap;
	}
	public HttpResponse getResponse(){
		return response;
	}
	public DocusignOAuth getOAuth(){
		return oAuth;
	}
	
	public class DocuSignException extends Exception {}
}