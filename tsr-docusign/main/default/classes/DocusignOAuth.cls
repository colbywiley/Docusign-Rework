/**
 * Docusign OAuth authentication class
 */
public with sharing class DocusignOAuth {
	static final String ACCESS_TOKEN_KEY = 'access_token';
	static final String EXPIRES_IN = 'expires_in';
	static final String DOCUSIGN_AUTHORIZATION_HEADER = 'Authorization';
	static final String CONTENT_TYPE_TEXT = 'Content-Type';
	static final String APPLICATION_JSON_TEXT = 'application/json';
	static final String GET_TEXT = 'GET';
	static final String BASE_PATH = '/restapi/v2';

	@TestVisible
	static final String DOCUSIGN_SETTING_ERROR = Label.Docusign_Setting_Error;
	@TestVisible
	static final String MISSING_ACCESS_TOKEN = Label.Missing_Access_Token;
	@TestVisible
	static final String DESERIALIZE_JSON_ERROR = Label.Deserialize_JSON_Error;
	@TestVisible
	static final String CANNOT_GET_BASE_URI = Label.Cannot_Get_Base_URI;
	@TestVisible
	static final String DOCUSIGN_BUILD_JWS_FAILURE = Label.Docusign_Build_JWS_Failure;
	@TestVisible
	static final String UNKNOWN_ERROR = Label.Unknown_Error;

	static final String ACCOUNTS_FIELD = 'accounts';
	static final String ACCOUNT_Id_FIELD = 'account_id';
	static final String BASE_URI_FIELD = 'base_uri';
	static final String ERROR_FIELD = 'error';
	static final String USER_AUTHENTICATION_FAILED = 'USER_AUTHENTICATION_FAILED';
	static final Map<String, String> errorMap = new Map<String, String>{
		'invalid_grant' => Label.Invalid_Grant,
		'consent_required' => Label.Consent_Required
	};

	@TestVisible
	private DocusignAccessToken accessTokenSetting {get; set;}
	private DocusignOptions options {get; set;}
	
	public static Boolean isUserAuthenticationFailed(String errorCode){
		return errorCode == USER_AUTHENTICATION_FAILED;
	}

	public DocusignOAuth(){
		accessTokenSetting = new DocusignAccessToken();
		options = new DocusignOptions();
		// Get access token if previous saved one in the custom setting is valid
		// otherwise obtain it from oauth api
		if(!accessTokenSetting.validate()){
			obtainAccessToken();
		}
	}

	public void obtainAccessToken(){
		if(!options.validate()){
			throw new DocusignOAuthException(DOCUSIGN_SETTING_ERROR);
		}
		// Unit test for Obtain access token does not work even you try to use mock service
		// https://salesforce.stackexchange.com/questions/174406/how-do-you-use-a-mock-response-when-calling-auth-jwtbearertokenexchange-getacces
		// also cannot create Certificate and Key Management record in test, so will move all jwt stuff to isRunningTest
		String responseBody;
		if (!Test.isRunningTest()) {     
			Auth.JWT jwt = new Auth.JWT();
			jwt.setSub(options.userId);
			jwt.setAud(options.authenticationService);
			jwt.setIss(options.integratorKey);
			jwt.setValidityLength(600);
			// Additional claims to set scope
			Map<String, Object> claims = new Map<String, Object>();
			claims.put('scope', 'signature');

			jwt.setAdditionalClaims(claims);
			String jsonStr = jwt.toJSONString();
			Auth.JWS jws;
			try {
				jws = new Auth.JWS(jwt, options.certificateLabel);
				// try encode and build jwt token
				jws.getCompactSerialization();
			} catch (Exception e) {
				throw new DocusignOAuthException(DOCUSIGN_BUILD_JWS_FAILURE);
			}

			String tokenEndpoint = options.oAuthLogin;               
			Auth.JWTBearerTokenExchange bearer = new Auth.JWTBearerTokenExchange(tokenEndpoint, jws);
			System.HttpResponse response = bearer.getHttpResponse();
			responseBody = response.getBody();          
		} else {     
			// TODO how to mock returned error in unit test?
			responseBody = '{"access_token": "abcdefg","expires_in": 3600}';             
		} 
		Map<String, Object> responseBodyMap;
		try {
			responseBodyMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);	
		} catch (JSONException e) {
			throw new DocusignOAuthException(DESERIALIZE_JSON_ERROR);
		}
		String error = String.valueOf(responseBodyMap.get(ERROR_FIELD));
		if(String.isNotBlank(error)){
			String errorMsg = errorMap.get(error);
			if(String.isBlank(errorMsg)){
				errorMsg = UNKNOWN_ERROR;
			}
			throw new DocusignOAuthException(errorMsg);
		}
		accessTokenSetting.accessToken = String.valueOf(responseBodyMap.get(ACCESS_TOKEN_KEY));
		// The number of seconds before the access token expires
		Integer expiresIn = Integer.valueOf(responseBodyMap.get(EXPIRES_IN));
		accessTokenSetting.expiryDateTime = Datetime.now().addSeconds(expiresIn);
		String baseUri = getBaseUri();
		accessTokenSetting.baseUri = baseUri;
		// here cannot save the latest valid access token automatically, it could cause unexpected exception
		// see doUpsert in DocusignAccessToken.cls to know about the detail
	}
	
	public void upsertAccessTokenSetting(){
		accessTokenSetting.doUpsert();
	}

	public String getAccessToken(){
		return accessTokenSetting.accessToken;
	}
	public DocusignAccessToken getAccessTokenSetting(){
		return accessTokenSetting;
	}

	public String getBaseUri(){
		if(String.isNotBlank(accessTokenSetting.baseUri) && accessTokenSetting.validate()){
			return accessTokenSetting.baseUri;
		}
		if(!options.validate()){
			throw new DocusignOAuthException(DOCUSIGN_SETTING_ERROR);
		}
		String accessToken = getAccessToken();
		if(String.isBlank(accessToken)){
			throw new DocusignOAuthException(MISSING_ACCESS_TOKEN);
		}
		HttpRequest request = new HttpRequest();
        request.setTimeout(new DocusignOptions().timeout);
		request.setMethod(GET_TEXT);
		request.setEndpoint(options.userInfoEndpoint);
        request.setHeader(CONTENT_TYPE_TEXT, APPLICATION_JSON_TEXT);
		request.setHeader(DOCUSIGN_AUTHORIZATION_HEADER, 'Bearer ' + accessToken);
		Http http = new Http();
		HttpResponse response = http.send(request);
		Map<String, Object> responseBodyMap;
		try {
			responseBodyMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());	
		} catch (JSONException e) {
			throw new DocusignOAuthException(DESERIALIZE_JSON_ERROR);
		}
		List<Object> accounts = (List<Object>) responseBodyMap.get(ACCOUNTS_FIELD);
		for(Object account : accounts){
			Map<String, Object> acctInfo = (Map<String, Object>) account;
			if(acctInfo.get(ACCOUNT_Id_Field) == options.accountId){
				return String.valueOf(acctInfo.get(BASE_URI_FIELD)) + BASE_PATH + '/accounts/' + options.accountId;
			}
		}
		throw new DocusignOAuthException(CANNOT_GET_BASE_URI);
	}
	
	public class DocusignOAuthException extends Exception {}
}