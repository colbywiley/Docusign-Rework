/**
 * DocusignTest
 * @description Test class for Docusign
 * @author Thomas Tran, Traction on Demand
 * @date 02-09-2017
 */
@isTest(seeAllData=false)
private class DocusignTest {
	static{
		insert DocusignTestDataFactory.createDocusignConfig();
		insert DocusignTestDataFactory.createDocusignFieldMapping();
	}

	@isTest static void createEnvelope() {
		TREX1__Contract_or_Form_Template__c template = DocusignTestDataFactory.createContractTemplate();
		template.Third_Party_Template_Id__c = 'a64abecb-0b7d-4bb3-a991-78f69355cc97';
		template.TREX1__Contract_Expiry_Policy__c = 'At Date';
		template.TREX1__Contract_Valid_For__c = 'Account';
		template.TREX1__Form_Type__c = 'Docusign Form';
		template.TREX1__Valid_Until_Date__c = Date.today().addDays(30);
		template.TREX1__Valid_for_Month_Length__c = 12;
		insert template;

		TREX1__Required_Contract_and_Form__c reqForm = DocusignTestDataFactory.createRequiredContractForm();
		reqForm.TREX1__Contract_or_Form_Template__c = template.Id;

		insert reqForm;

		TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
		form.TREX1__Third_Party_Envelope_Id__c = 'asdasd-asdsad-asdasdad-asdasd';
		form.TREX1__Type__c = 'Docusign Form';
		form.TREX1__Template_ID__c = template.Id;
		insert form;

		Contact newContact = DocusignTestDataFactory.createContact();
		newContact.FirstName = 'Test';
		newContact.LastName = 'Test';
		newContact.Email = 'test@test.test';
		insert newContact;

		Contact resultContact = [SELECT Name, Email FROM Contact WHERE Id = :newContact.Id][0];

		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		Test.startTest();

		Docusign newDocusign = new Docusign(form.Id, null, 'Sign', new List<String>{'asdasd-asdsad-asdasdad-asdasd'}, resultContact, 'www.test.test');
		String envelopeId = newDocusign.createEnvelope();

		Test.stopTest();

		System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948', envelopeId);
	}

	@isTest static void getPostRecipientView() {
		TREX1__Contract_or_Form_Template__c template = DocusignTestDataFactory.createContractTemplate();
		template.Third_Party_Template_Id__c = 'a64abecb-0b7d-4bb3-a991-78f69355cc97';
		template.TREX1__Contract_Expiry_Policy__c = 'At Date';
		template.TREX1__Contract_Valid_For__c = 'Account';
		template.TREX1__Form_Type__c = 'Docusign Form';
		template.TREX1__Valid_Until_Date__c = Date.today().addDays(30);
		template.TREX1__Valid_for_Month_Length__c = 12;
		insert template;

		TREX1__Required_Contract_and_Form__c reqForm = DocusignTestDataFactory.createRequiredContractForm();
		reqForm.TREX1__Contract_or_Form_Template__c = template.Id;

		insert reqForm;

		TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
		form.TREX1__Third_Party_Envelope_Id__c = 'asdasd-asdsad-asdasdad-asdasd';
		form.TREX1__Type__c = 'Docusign Form';
		form.TREX1__Template_ID__c = template.Id;
		insert form;

		Contact newContact = DocusignTestDataFactory.createContact();
		newContact.FirstName = 'Test';
		newContact.LastName = 'Test';
		newContact.Email = 'test@test.test';
		insert newContact;

		Contact resultContact = [SELECT Name, Email FROM Contact WHERE Id = :newContact.Id][0];

		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/views/recipient', 'Docusign_Post_Recipient_View');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		Test.startTest();

		Docusign newDocusign = new Docusign(form.Id, null, 'Sign', new List<String>{'asdasd-asdsad-asdasdad-asdasd'}, resultContact, 'www.test.test');
		String envelopeId = newDocusign.createEnvelope();
		String url = newDocusign.getPostRecipientView();

		Test.stopTest();

		System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948', envelopeId);
		System.assertEquals('https://demo.docusign.net/Signing/startinsession.aspx?t=99e4e2cc-42f4-4569-ae14-154e70870bb4', url);
	}

	@isTest static void getEnvelopeDocuments() {
		TREX1__Contract_or_Form_Template__c template = DocusignTestDataFactory.createContractTemplate();
		template.Third_Party_Template_Id__c = 'a64abecb-0b7d-4bb3-a991-78f69355cc97';
		template.TREX1__Contract_Expiry_Policy__c = 'At Date';
		template.TREX1__Contract_Valid_For__c = 'Account';
		template.TREX1__Form_Type__c = 'Docusign Form';
		template.TREX1__Valid_Until_Date__c = Date.today().addDays(30);
		template.TREX1__Valid_for_Month_Length__c = 12;
		insert template;

		TREX1__Required_Contract_and_Form__c reqForm = DocusignTestDataFactory.createRequiredContractForm();
		reqForm.TREX1__Contract_or_Form_Template__c = template.Id;

		insert reqForm;

		TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
		form.TREX1__Third_Party_Envelope_Id__c = 'asdasd-asdsad-asdasdad-asdasd';
		form.TREX1__Type__c = 'Docusign Form';
		form.TREX1__Template_ID__c = template.Id;
		insert form;

		Contact newContact = DocusignTestDataFactory.createContact();
		newContact.FirstName = 'Test';
		newContact.LastName = 'Test';
		newContact.Email = 'test@test.test';
		insert newContact;

		Contact resultContact = [SELECT Name, Email FROM Contact WHERE Id = :newContact.Id][0];

		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/documents/combined', 'Docusign_Envelope_Document');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		Test.startTest();

		Docusign newDocusign = new Docusign(form.Id, null, 'Sign', new List<String>{'asdasd-asdsad-asdasdad-asdasd'}, resultContact, 'www.test.test');
		String envelopeId = newDocusign.createEnvelope();
		Attachment newAttachment = newDocusign.getEnvelopeDocuments();

		Test.stopTest();

		System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948', envelopeId);
		System.assert(newAttachment != null);
	}

	@isTest static void docusignResendEmail() {
		TREX1__Contract_or_Form_Template__c template = DocusignTestDataFactory.createContractTemplate();
		template.Third_Party_Template_Id__c = 'a64abecb-0b7d-4bb3-a991-78f69355cc97';
		template.TREX1__Contract_Expiry_Policy__c = 'At Date';
		template.TREX1__Contract_Valid_For__c = 'Account';
		template.TREX1__Form_Type__c = 'Docusign Form';
		template.TREX1__Valid_Until_Date__c = Date.today().addDays(30);
		template.TREX1__Valid_for_Month_Length__c = 12;
		insert template;

		TREX1__Required_Contract_and_Form__c reqForm = DocusignTestDataFactory.createRequiredContractForm();
		reqForm.TREX1__Contract_or_Form_Template__c = template.Id;

		insert reqForm;

		TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
		form.TREX1__Third_Party_Envelope_Id__c = 'asdasd-asdsad-asdasdad-asdasd';
		form.TREX1__Type__c = 'Docusign Form';
		form.TREX1__Template_ID__c = template.Id;
		insert form;

		Contact newContact = DocusignTestDataFactory.createContact();
		newContact.FirstName = 'Test';
		newContact.LastName = 'Test';
		newContact.Email = 'test@test.test';
		insert newContact;

		Contact resultContact = [SELECT Name, Email FROM Contact WHERE Id = :newContact.Id][0];

		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/asdasd-asdsad-asdasdad-asdasd/recipients?resend_envelope=true', 'Docusign_Resend_Envelope_Test');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);

		Test.startTest();

		Docusign newDocusign = new Docusign(form.Id, 'asdasd-asdsad-asdasdad-asdasd', 'Sign', new List<String>{'asdasd-asdsad-asdasdad-asdasd'}, resultContact, 'www.test.test');
		newDocusign.resendEnvelope();

		Test.stopTest();

		List<TREX1__Contract_And_Form__c> contracts = [SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_And_Form__c WHERE Id = :form.Id];
		System.assertEquals('asdasd-asdsad-asdasdad-asdasd' , contracts[0].TREX1__Third_Party_Envelope_Id__c);

	}
	
	@isTest static void createRequestNewRequest() {
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		DocusignRequest requestNull;
		DocusignRequest requestNew;
		Test.startTest();

		Docusign newDocusign = new Docusign();
		requestNull = newDocusign.dsRequest;
		newDocusign.createRequest('GET', '/test/path');
		requestNew = newDocusign.dsRequest;
		Test.stopTest();

		System.assert(requestNull == null, 'dsRequest is null when creating the new Docusign object');
		System.assert(requestNew != null, 'dsRequest is not null after call createRequest');
	}
	@isTest static void createAnotherRequest() {
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Test.startTest();

		Docusign newDocusign = new Docusign();
		DocusignRequest request1 = newDocusign.createRequest('GET', '/test/path');
		DocusignRequest request2 = newDocusign.createRequest('GET', '/test/another/path');
		Test.stopTest();

		System.assert(request1 != request2);
		System.assert(request1.oAuth == request2.oAuth, 'request1 and request2 should use the same oAuth object');
	}
}