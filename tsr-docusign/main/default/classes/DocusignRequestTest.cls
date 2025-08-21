@isTest(seeAllData=false)
private class DocusignRequestTest {
	static{
		insert DocusignTestDataFactory.createDocusignConfig();
		insert DocusignTestDataFactory.createDocusignFieldMapping();
	}
	static final String TEST_URI = 'https://demo.docusign.net/restapi/v2/login_information';
	static final String TEST_POST_URI = 'https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes';
	static final String USER_INFO_URI = 'https://account-d.docusign.com/oauth/userinfo';
	
	@isTest 
	static void testDocusignRequest_PassMethodAndPath() {
		
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(TEST_POST_URI, 'Docusign_Create_Envelope');
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		Test.startTest();

		DocusignRequest dr = new DocusignRequest('POST', '/envelopes').execute();

		Test.stopTest();

		System.assert(dr.oAuth != null, 'Should request have oAuth object');
		System.assertEquals('/envelopes', dr.path, 'Should path be correct');
		System.assertEquals(TEST_POST_URI, dr.request.getEndpoint(), 'Should endpoint be correct');
		System.assertEquals('POST', dr.request.getMethod().toUpperCase(), 'method should be correct');
		System.assert(dr.getResponseBodyMap() != null, 'Should deserialize returned JSON');
	}
	@isTest 
	static void testDocusignRequest_PassMethodAndPathAndDeserializeJSON() {
		
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(TEST_POST_URI, 'Docusign_Create_Envelope');
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		Test.startTest();

		DocusignRequest dr = new DocusignRequest('POST', '/envelopes', false).execute();

		Test.stopTest();

		System.assert(dr.oAuth != null, 'Should request have oAuth object');
		System.assertEquals('/envelopes', dr.path, 'Should path be correct');
		System.assertEquals(TEST_POST_URI, dr.request.getEndpoint(), 'Should endpoint be correct');
		System.assertEquals('POST', dr.request.getMethod().toUpperCase(), 'method should be correct');
		System.assert(dr.getResponseBodyMap() == null, 'Should not deserialize returned JSON');
	}
	@isTest 
	static void testDocusignRequest_Return200() {
		
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(TEST_URI, 'Docusign_Base_Url');
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		Test.startTest();

		DocusignRequest request = new DocusignRequest(buildRequest('GET', TEST_URI)).execute();

		Test.stopTest();
		Map<String, Object> responseBodyMap = request.getResponseBodyMap();
		List<Object> associatedAccounts = (List<Object>) responseBodyMap.get('loginAccounts');

		System.assert(associatedAccounts.size() > 0, 'Should return mock data correctly');
	}
	@isTest 
	static void testDocusignRequest_Return400() {

		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(TEST_URI, 'Docusign_Base_Url_400');
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(400);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Boolean exceptionThrown = false;
		String error = '';
		Test.startTest();
		try {
			DocusignRequest request = new DocusignRequest(buildRequest('GET', TEST_URI)).execute();	
		} catch (Exception e) {
			exceptionThrown = true;
			error = e.getMessage();
		}
		Test.stopTest();

		System.assert(exceptionThrown, 'Should throw exception');
		System.assertEquals('123 error text', error, 'Should error message be correct');
	}
	@isTest 
	static void testDocusignRequest_ReturnInvalidJSON() {

		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(TEST_URI, 'Docusign_Invalid_JSON');
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Boolean exceptionThrown = false;
		String error = '';
		Test.startTest();
		try {
			DocusignRequest request = new DocusignRequest(buildRequest('GET', TEST_URI)).execute();	
		} catch (Exception e) {
			exceptionThrown = true;
			error = e.getMessage();
		}
		Test.stopTest();

		System.assert(exceptionThrown, 'Should throw exception');
		System.assertEquals(DocusignRequest.DESERIALIZE_JSON_ERROR, error, 'Should error message be correct');
	}
	@isTest 
	static void testDocusignRequest_HasAuthenticationHeader() {
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Test.startTest();

		DocusignRequest docusignRequest = new DocusignRequest(buildRequest('GET', TEST_URI));
		System.assertEquals(
			'Bearer abcdefg', 
			docusignRequest.request.getHeader('Authorization'), 
			'Should request header contains Authorization and the value is correct'
		);
		Test.stopTest();
	}
	@isTest static void testDocusignRequest_CreateByBut() {
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Test.startTest();

		DocusignRequest request1 = new DocusignRequest('GET', '/test/path');
		DocusignRequest request2 = request1.but('POST', '/test/another/path');
		Test.stopTest();

		System.assert(request1.oAuth == request2.oAuth, 'request1 and request2 should use the same oAuth object');
		System.assertEquals('/test/path', request1.path, 'path should be correct');
		System.assertEquals('/test/another/path', request2.path, 'path should be correct');
		System.assertEquals('GET', request1.request.getMethod().toUpperCase() , 'method should be correct');
		System.assertEquals('POST', request2.request.getMethod().toUpperCase(), 'method should be correct');
	}
	@isTest static void testDocusignRequest_refreshAccessTokenAndExecute() {
		Docusign_Access_Token__c setting = new Docusign_Access_Token__c(
			Access_Token_Part1__c = 'invalid_access_token',
			Base_Uri__c = 'https://demo.docusign.net/restapi/v2/accounts/15898051',
			Expiry_DateTime__c = DateTime.now().addSeconds(3600)
		);
		insert setting;
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource(TEST_URI, 'Docusign_Base_Url');
		multimock.setStaticResource(USER_INFO_URI, 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		DocusignRequest dr = new DocusignRequest(buildRequest('GET', TEST_URI));
		String accessTokenInvalid = dr.oAuth.getAccessToken();

		Test.startTest();
		dr.refreshAccessTokenAndExecute();
		Test.stopTest();
		String accessTokenValid = dr.oAuth.getAccessToken();

		System.assertEquals('invalid_access_token', accessTokenInvalid, 'Should access token be invalid one');
		System.assertEquals('abcdefg', accessTokenValid, 'Should access token be valid one');
		System.assertEquals('Bearer abcdefg', dr.request.getHeader('Authorization'), 'Should authorization header is the valid access token');
	}

	static HttpRequest buildRequest (String methodType, String endPoint) {
		HttpRequest request = new HttpRequest();
		request.setEndpoint(endPoint);
        request.setMethod(methodType);
        request.setHeader('Content-Type', 'application/json');

		return request;

	}
}