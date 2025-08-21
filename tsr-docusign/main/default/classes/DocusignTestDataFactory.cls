@isTest
public class DocusignTestDataFactory {
    public static TREX1__App_Config__c createOrgDefaultAppConfig() {
		TREX1__App_Config__c ac = TREX1__App_Config__c.getOrgDefaults();
		ac.TREX1__Minimum_Contract_Signing_Age__c = 18;
		return ac;
	}
	
	public static Docusign_Settings__c createDocusignConfig(){
        Docusign_Settings__c config = new Docusign_Settings__c(
            Integrator_Key__c = '0fee914d-5331-4a21-87d6-dbfe1349ae7b',
            Certificate_Label__c = 'testdocusign',
            Authentication_Service__c = 'account-d.docusign.com',
            OAuth_Login__c = 'https://account-d.docusign.com/oauth/token',
            User_Id__c = 'eb28a8a4-7e32-4eda-ad70-8c02aacb48f3',
            Account_Id__c = '15898051',
            User_Info_Endpoint__c = 'https://account-d.docusign.com/oauth/userinfo',
            Redirect_Uri__c = 'https://trex-dev.my.salesforce.com/apex/DocusignCallback',
            Timeout__c = 120000
        );

        return config;
    }
	public static Docusign_Access_Token__c createAccessTokenSetting(){
        Docusign_Access_Token__c setting = new Docusign_Access_Token__c(
            Access_Token_Part1__c = 'abcdefg',
            Base_Uri__c = 'https://demo.docusign.net/restapi/v2/accounts/15898051',
            Expiry_DateTime__c = DateTime.now().addSeconds(3600)
        );

        return setting;
    }
    
	public static String getAccessToken(Docusign_Access_Token__c docusignAccessTokenSetting){
		String accessToken = docusignAccessTokenSetting.Access_Token_Part1__c;
		if(docusignAccessTokenSetting.Access_Token_Part2__c != null){
			accessToken += docusignAccessTokenSetting.Access_Token_Part2__c;
		}
		if(docusignAccessTokenSetting.Access_Token_Part3__c != null){
			accessToken += docusignAccessTokenSetting.Access_Token_Part3__c;
		}
		if(docusignAccessTokenSetting.Access_Token_Part4__c != null){
			accessToken += docusignAccessTokenSetting.Access_Token_Part4__c;
		}
		return accessToken;
	}

    public static Docusign_Field_Mappings__c createDocusignFieldMapping(){
        Docusign_Field_Mappings__c config = new Docusign_Field_Mappings__c(
        	Name = 'Contract Name',
            Data_Type__c = 'String',
            Sobject_Type__c = 'TREX1__Contract_and_Form__c',
            Source_Field__c	 = 'Name',
            Target_Field__c = 'Contract Name',
            Template_Id__c = '3843cfb1-6f19-4d6d-a4cc-cb745ddce019'
        );

        return config;
    }

    public static TREX1__Contract_or_Form_Template__c createContractTemplate() {
        return createContractTemplates(1)[0];
    }

    public static List<TREX1__Contract_or_Form_Template__c> createContractTemplates(Integer count) {
        List<TREX1__Contract_or_Form_Template__c> records =
                (List<TREX1__Contract_or_Form_Template__c>) createSObjects(TREX1__Contract_or_Form_Template__c.SObjectType, count);

        return records;
    }

    public static TREX1__Required_Contract_and_Form__c createRequiredContractForm() {
        return createRequiredContractForms(1)[0];
    }

    public static List<TREX1__Required_Contract_and_Form__c> createRequiredContractForms(Integer count) {
        List<TREX1__Required_Contract_and_Form__c> records =
                (List<TREX1__Required_Contract_and_Form__c>) createSObjects(TREX1__Required_Contract_and_Form__c.SObjectType, count);
        return records;
    }

	public static TREX1__Contract_and_Form__c createContractAndForm(){
        return createContractAndForms(1)[0];
    }

    public static List<TREX1__Contract_and_Form__c> createContractAndForms(Integer count) {
        List<TREX1__Contract_and_Form__c> records =
            (List<TREX1__Contract_and_Form__c>)createSObjects(TREX1__Contract_and_Form__c.SObjectType, count);

        for (TREX1__Contract_and_Form__c record : records) {
            record.TREX1__Valid_For__c = 'Account';
        }

        return records;
    }
	
	public static Contact createContact() {
        return createContacts(1)[0];
    }

    public static List<Contact> createContacts(Integer count) {
        List<Contact> records =
            (List<Contact>)createSObjects(Contact.SObjectType, count);

        Integer i = 0;
        for(Contact record : records) {
            record.LastName = 'test' + i++;
        }
        return records;
    }

    private static List<SObject> createSObjects(Schema.SObjectType sType, Integer num) {
        return createSObjects(sType, num, new Map<String, Object>());
    }

    private static List<sObject> createSObjects(SObjectType sType, Integer count, Map<String, Object> defaultValues) {
        List<SObject> sObjs = new List<SObject>();
        for (Integer i = 0; i < count; i++) {
            SObject newObj = sType.newSObject();
            setRecordFieldsValues(newObj, defaultValues);
            sObjs.add(newObj);
        }
        return sObjs;
    }

    public static void setRecordFieldsValues(sObject record, Map<String, Object> recordFields){
        for(String fieldName : recordFields.keySet()) {
            record.put(fieldName, recordFields.get(fieldName));
        }
    }
	
}