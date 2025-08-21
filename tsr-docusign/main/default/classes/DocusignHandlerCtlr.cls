/**
 * DocusignHandlerCtlr
 * @description Handle docusign request and response flows.
 * @author Thomas Tran, Traction on Demand
 * @date 01-24-2017
 */
public without sharing class DocusignHandlerCtlr {
	private static final String PL_CAPTURE_STATUS_IN_PERSON     = 'In Person';
	private static final String PL_CAPTURE_STATUS_VIA_EMAIL      = 'Via Email';
	private static final String EMAIL_DOCUMENT     = 'Email';
	private static final String SIGN_DOCUMENT      = 'Sign';
	private static final String CONTRACT_SENT      = 'Sent';
	private static final String CONTRACT_COMPLETE  = 'Complete';
	private static final String COMPLETED_DOCUMENT = 'Completed Docusign Document';
	private static final TREX1__App_Config__c APP_CONFIG = TREX1__App_Config__c.getOrgDefaults();

	/**
	 * docusignEmail
	 * @description Callout to get send the contract through email.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-24-2017
	 */
	@AuraEnabled
	public static DocusignResult docusignEmail(String contractAndFormId){
		DocusignResult result = new DocusignResult();

		try{
			String envelopeId;
			//TODO: GATHER DATA
			ContractData contract = getContractData(contractAndFormId);
			if(String.isNotBlank(contract.contractAndForm.TREX1__Capture_Status__c) && String.isNotBlank(contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c)){
				result = docusignResend(contractAndFormId);
				if(result.isSuccess){
					result.result = contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c;
				}
				return result;
			}
			if(contract != null){
				List<String> templateIds = new List<String>();
				templateIds.add(contract.template.Third_Party_Template_Id__c);

				//TODO: Get field mappings
				Docusign ds = new Docusign(contractAndFormId, contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c, EMAIL_DOCUMENT, templateIds,
											contract.currentContact, URL.getSalesforceBaseUrl().toExternalForm() + '/c/DocusignHandler.app?recordId=' + contractAndFormId + '&flowType=Finish');
				envelopeId = ds.createEnvelope();

				ds.upsertAccessTokenSetting();

				if(String.isBlank(contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c)){
					updateContractAndFormWithEnvelopeId(contractAndFormId, envelopeId, CONTRACT_SENT, PL_CAPTURE_STATUS_VIA_EMAIL);
				}
				
				result.isSuccess = true;
				result.result = envelopeId;
			}
		} catch(Exception ex){
			result.isSuccess = false;
			result.errorMessage = ex.getMessage();
		}

		return result;
	}

	/**
	 * docusignSign
	 * @description Callout to get the docusign url to sign immediately
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-24-2017
	 */
	@AuraEnabled
	public static DocusignResult docusignSign(String contractAndFormId){
		DocusignResult result = new DocusignResult();

		try{
			String docusignURL;
			String envelopeId;
			//TODO: GATHER DATA
			ContractData contract = getContractData(contractAndFormId);

			if(contract != null){
				if(String.isBlank(contract.template.Third_Party_Template_Id__c)) {
					throw new DocusignException('Third party template id is blank - check permissions');
				}
				List<String> templateIds = new List<String>();
				templateIds.add(contract.template.Third_Party_Template_Id__c);

				final ConnectApi.Community community = DocusignCommunityService.isCurrentRequestCommunity() ? DocusignCommunityService.getCurrentRequestCommunity() : null;

				//TODO: Get field mappings
				Docusign ds = new Docusign(contractAndFormId, contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c, SIGN_DOCUMENT, templateIds,
					contract.currentContact, URL.getSalesforceBaseUrl().toExternalForm() + (community != null && community.urlPathPrefix != null ? '/' + community.urlPathPrefix : '') + '/c/DocusignHandler.app?recordId=' + contractAndFormId + '&flowType=Finish');
				docusignURL = ds.getPostRecipientView();
				envelopeId = ds.options.envelopeId;

                ds.upsertAccessTokenSetting();
				if(String.isBlank(contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c)){
					updateContractAndFormWithEnvelopeId(contractAndFormId, envelopeId, CONTRACT_SENT, PL_CAPTURE_STATUS_IN_PERSON);
				}

				result.isSuccess = true;
				result.result = docusignURL;
			}
		} catch(Exception ex){
			System.debug(LoggingLevel.ERROR, ex.getStackTraceString());
			result.isSuccess = false;
			result.errorMessage = ex.getMessage();
		}

		return result;
	}

	/**
	 * docusignResend
	 * @description Callout to get the docusign url to sign immediately
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-24-2017
	 */
	@AuraEnabled
	public static DocusignResult docusignResend(String contractAndFormId){
		DocusignResult result = new DocusignResult();

		try{
			ContractData contract = getContractData(contractAndFormId);

			if(contract != null){
				if(String.isBlank(contract.template.Third_Party_Template_Id__c)) {
					throw new DocusignException('Third party template id is blank - check permissions');
				}
				List<String> templateIds = new List<String>();
				templateIds.add(contract.template.Third_Party_Template_Id__c);

				final ConnectApi.Community community = DocusignCommunityService.isCurrentRequestCommunity() ? DocusignCommunityService.getCurrentRequestCommunity() : null;

				Docusign ds = new Docusign(contractAndFormId, contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c, '', templateIds,
						contract.currentContact, URL.getSalesforceBaseUrl().toExternalForm() + (community != null && community.urlPathPrefix != null ? '/' + community.urlPathPrefix : '') + '/c/DocusignHandler.app?recordId=' + contractAndFormId + '&flowType=Finish');
				ds.resendEnvelope();

                ds.upsertAccessTokenSetting();
				result.isSuccess = true;
			}
		} catch(Exception ex){
			result.isSuccess = false;
			result.errorMessage = ex.getMessage();
		}

		return result;
	}

	/**
	 * docusignPDF
	 * @description Callout to get the docusign PDF of the envelope
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-24-2017
	 */
	@AuraEnabled
	public static DocusignResult docusignPDF(String contractAndFormId){
		DocusignResult result = new DocusignResult();

		try{
			//if(!hasCompleteDocusign(contractAndFormId)){
				//TODO: GATHER DATA
				ContractData contract = getContractData(contractAndFormId);

				if(contract != null){
					List<String> templateIds = new List<String>();
					templateIds.add(contract.template.Third_Party_Template_Id__c);

					Docusign ds = new Docusign(contractAndFormId, contract.contractAndForm.TREX1__Third_Party_Envelope_Id__c, '', templateIds,
						contract.currentContact, URL.getSalesforceBaseUrl().toExternalForm() + '/c/DocusignHandler.app?recordId=' + contractAndFormId + '&flowType=Finish');

					insert ds.getEnvelopeDocuments();
					ds.upsertAccessTokenSetting();
				}
			//}

			result.isSuccess = true;

		} catch(Exception ex){
			result.isSuccess = false;
			result.errorMessage = ex.getMessage();
		}

		return result;
	}

	/**
	 * updateContractToSigned
	 * @description Change the contract to signed
	 * @author Thomas Tran, Traction on Demand
	 * @date 02-07-2017
	 */
	@AuraEnabled
	public static DocusignResult updateContractToSigned(String contractAndFormId){
		DocusignResult result = new DocusignResult();

		try{
			update new TREX1__Contract_And_Form__c(Id = contractAndFormId, TREX1__Has_Been_Signed__c = true, TREX1__Status__c = CONTRACT_COMPLETE);

	        result.isSuccess = true;
        }catch(Exception ex){
        	result.isSuccess = false;
			result.errorMessage = ex.getMessage();
        }

        return result;
	}

	/**
	 * hasCompleteDocusign
	 * @description Checks if the current contract has a docusign document attached.
	 * @author Thomas Tran, Traction on Demand
	 * @date 02-07-2017
	 */
	private static Boolean hasCompleteDocusign(String contractAndFormId){
		List<Attachment> docusignAttachments = [SELECT Id, Name, ParentId FROM Attachment WHERE ParentId = :contractAndFormId AND Name = :COMPLETED_DOCUMENT];

        return !docusignAttachments.isEmpty();
	}

	/**
	 * getContractAndFormData
	 * @description Retrieves the necessary data needed for docusign.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-23-2017
	 */
	private static ContractData getContractData(Id contractAndFormId){
		TREX1__Contract_And_Form__c currentContract;
		TREX1__Contract_Or_Form_Template__c associatedTemplate;
		Contact currentContact;

		if(APP_CONFIG.TREX1__Minimum_Contract_Signing_Age__c == null){
			throw new DocusignException('Minimum signing age has not been set on the app config');
		}

		List<TREX1__Contract_And_Form__c> contractAndForms = [
			SELECT Id, TREX1__Contact__c, TREX1__Contact__r.Name, TREX1__Contact__r.Email, TREX1__Template_Id__c, TREX1__Third_Party_Envelope_Id__c, TREX1__Primary_Contact_Signature__c, 
				   TREX1__Transaction__r.TREX1__Account__r.TREX1__Primary_Contact__c, TREX1__Contact__r.TREX1__Age__c, TREX1__Capture_Status__c
			FROM TREX1__Contract_And_Form__c
			WHERE Id = :contractAndFormId
		];

		if(!contractAndForms.isEmpty()){
			currentContract = contractAndForms[0];
		}

		if(currentContract != null && String.isNotBlank(currentContract.TREX1__Template_Id__c)){
			if(!TREX1__Contract_Or_Form_Template__c.Third_Party_Template_Id__c.getDescribe().isAccessible()) {
				throw new DocusignException('Can not read TREX1__Third_Party_Template_Id__c on TREX1__Contract_Or_Form_Template__c');
			}
			List<TREX1__Contract_Or_Form_Template__c> contractAndFormTemplates = [
				SELECT Id, Third_Party_Template_Id__c
				FROM TREX1__Contract_Or_Form_Template__c
				WHERE Id = :currentContract.TREX1__Template_Id__c
			];

			if(!contractAndFormTemplates.isEmpty()){
				associatedTemplate = contractAndFormTemplates[0];
				if(associatedTemplate.Third_Party_Template_Id__c == null) {
					throw new DocusignException('Queried template has no Third_Party_Template_Id__c, ' + associatedTemplate.Id);
				}
			}
        }

         if(currentContract != null){
         	if(currentContract.TREX1__Primary_Contact_Signature__c || (currentContract.TREX1__Contact__r.TREX1__Age__c < APP_CONFIG.TREX1__Minimum_Contract_Signing_Age__c)){
				if(String.isNotBlank(currentContract.TREX1__Transaction__r.TREX1__Account__r.TREX1__Primary_Contact__c)){
					List<Contact> contacts = [
						SELECT Id, Name, Email
						FROM Contact
						WHERE Id = :currentContract.TREX1__Transaction__r.TREX1__Account__r.TREX1__Primary_Contact__c
					];

					if(!contacts.isEmpty()){
						currentContact = contacts[0];
					}
				} else{
					throw new DocusignException('Primary Contact Not Assigned to the Account.');
				}
			} else{
				if(String.isNotBlank(currentContract.TREX1__Contact__c)){
					List<Contact> contacts = [
						SELECT Id, Name, Email
						FROM Contact
						WHERE Id = :currentContract.TREX1__Contact__c
					];

					if(!contacts.isEmpty()){
						currentContact = contacts[0];
					}
				} else{
					throw new DocusignException('Contact Not Assigned to the Contract.');
				}
			}
        }

        return new ContractData(currentContract, associatedTemplate, currentContact);
	}

	/**
	 * ContractData
	 * @description Stores the current contract and form and related template.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-23-2017
	 */
	public class ContractData{
	 	public TREX1__Contract_And_Form__c contractAndForm {get; set;}
	 	public TREX1__Contract_Or_Form_Template__c template {get; set;}
	 	public Contact currentContact {get; set;}

	 	public ContractData(TREX1__Contract_And_Form__c contractAndForm, TREX1__Contract_Or_Form_Template__c template, Contact currentContact){
	 		this.contractAndForm = contractAndForm;
	 		this.template = template;
	 		this.currentContact = currentContact;
	 	}
	}

	/**
	 * DocusignResult
	 * @description Groups the results of the callout.
	 * @author Thomas Tran, Traction on Demand
	 * @date 02-07-2017
	 */
	public class DocusignResult{
	 	@AuraEnabled
	 	public String result {get; set;}
	 	@AuraEnabled
	 	public String errorMessage {get; set;}
	 	@AuraEnabled
	 	public Boolean isSuccess {get; set;}
	 }

	/**
	 * updateContractAndFormWithEnvelopeId
	 * @description Updates the contract and form with the envelope id returned
	 *              by docusign.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-24-2017
	 */
	 private static void updateContractAndFormWithEnvelopeId(Id contractAndFormId, String envelopeId, String status, String captureStatus){
	 	upsert new TREX1__Contract_And_Form__c(Id = contractAndFormId, TREX1__Third_Party_Envelope_Id__c = envelopeId, TREX1__Status__c = status, TREX1__Capture_Status__c = captureStatus);
	 }

	/**
	 * Exceptions
	 */
	public class DocusignException extends Exception {}

}