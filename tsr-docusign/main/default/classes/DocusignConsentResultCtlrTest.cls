@isTest(seeAllData=false)
private class DocusignConsentResultCtlrTest {
	static{
		insert DocusignTestDataFactory.createDocusignConfig();
	}

	@isTest static void getDocusignConfig() {
		Test.startTest();
		DocusignConsentResultCtlr.DocusignConfigResult result = DocusignConsentResultCtlr.getDocusignConfig();
		Test.stopTest();
		System.assert(result.isSuccess);
		System.assertEquals('0fee914d-5331-4a21-87d6-dbfe1349ae7b', result.integratorKey);
		System.assertEquals('https://trex-dev.my.salesforce.com/apex/DocusignCallback', result.redirectUri);
		System.assertEquals('account-d.docusign.com', result.authenticationService);
	}

	@isTest static void checkOAuthValid_valid() {
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		
		Test.startTest();
		DocusignConsentResultCtlr.DocusignConfigResult result = DocusignConsentResultCtlr.checkOAuthValid();
		Test.stopTest();

		System.assert(result.isSuccess);
	}
	@isTest static void checkOAuthValid_invalid() {
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info_Empty_Account');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Test.startTest();
		DocusignConsentResultCtlr.DocusignConfigResult result = DocusignConsentResultCtlr.checkOAuthValid();
		Test.stopTest();

		System.assert(!result.isSuccess);
		System.assertEquals(Label.Cannot_Get_Base_URI, result.errorMessage);
	}
}