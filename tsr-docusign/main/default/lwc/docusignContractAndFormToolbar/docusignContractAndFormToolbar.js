import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue  } from 'lightning/uiRecordApi';
import getContract from "@salesforce/apex/DocusignContractAndFormToolbarController.getContract";
import STATUS_FIELD from '@salesforce/schema/TREX1__Contract_and_Form__c.TREX1__Status__c';
import TYPE_FIELD from '@salesforce/schema/TREX1__Contract_and_Form__c.TREX1__Type__c';
import SIGNED_CONTRACT_RETRIEVED_FIELD from '@salesforce/schema/TREX1__Contract_and_Form__c.Signed_Contract_Retrieved__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DocusignContractAndFormToolbar extends LightningElement {
    @api
    recordId;

    @track
    showSpinner = false;

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, TYPE_FIELD, SIGNED_CONTRACT_RETRIEVED_FIELD]})
    contractAndForm;
    
    handleGetContract() {
        let contractStatus = getFieldValue(this.contractAndForm.data, STATUS_FIELD);
        let contractType = getFieldValue(this.contractAndForm.data, TYPE_FIELD);
        let signedContractRetrieved = getFieldValue(this.contractAndForm.data, SIGNED_CONTRACT_RETRIEVED_FIELD);

        if(signedContractRetrieved) {
            this.handleShowToastMessage('Warning', 'Contract has already been retrieved', 'warning');
            return;
        }

        if(contractType != 'Docusign Form') {
            this.handleShowToastMessage('Warning', 'Contract type must be Docusign Form', 'warning');
            return;
        }

        if(contractStatus == 'Complete') {
            this.showSpinner = true;
            getContract({
                contractId: this.recordId
            }).then(
                 result => {
                    this.showSpinner = false;
                    this.handleShowToastMessage('Success', 'Success', 'success');
                    location.reload();
                }
            ).catch(
                error => {
                    this.showSpinner = false;
                    this.handleShowToastMessage('Error', this.formatErrorString(error), 'error');
                }
            );
        } else {
            this.handleShowToastMessage('Warning', 'To retrieve the contract, it must have the status of Complete', 'warning');
        }
    }

    handleShowToastMessage(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    formatErrorString(errors) {
        let listOfErrors = this.getListOfErrors(errors);
        let errorMsg = '';

        for(let msg of listOfErrors) {
            errorMsg += msg + ' ';
        }

        return errorMsg;
    }

    getListOfErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }
    
        return (
            errors
                .filter((error) => !!error)
                .map((error) => {
                    if (Array.isArray(error.body)) {
                        return error.body.map((e) => e.message);
                    }
                    else if (error.body && typeof error.body.message === 'string') {
                        return error.body.message;
                    }
                    else if (typeof error.message === 'string') {
                        return error.message;
                    }
                    return error.statusText;
                })
                .reduce((prev, curr) => prev.concat(curr), [])
                .filter((message) => !!message)
        );
    }
}