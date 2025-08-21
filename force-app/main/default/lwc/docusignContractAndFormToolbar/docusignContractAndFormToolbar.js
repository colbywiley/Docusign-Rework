import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getContract from "@salesforce/apex/DocusignContractAndFormToolbarController.getContract";
import STATUS_FIELD from '@salesforce/schema/TREX1__Contract_and_Form__c.TREX1__Status__c';
import SIGNED_CONTRACT_RETRIEVED_FIELD from '@salesforce/schema/TREX1__Contract_and_Form__c.Signed_Contract_Retrieved__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DocusignContractAndFormToolbar extends LightningElement {
    @api recordId;
    @track showSpinner = false;

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, SIGNED_CONTRACT_RETRIEVED_FIELD]})
    contractAndForm;

    handleGetContract() {
        const status = getFieldValue(this.contractAndForm.data, STATUS_FIELD);
        const isRetrieved = getFieldValue(this.contractAndForm.data, SIGNED_CONTRACT_RETRIEVED_FIELD);

        if (isRetrieved) {
            this.toast('Notice', 'Contract has already been retrieved', 'warning');
            return;
        }
        if (status !== 'Complete') {
            this.toast('Warning', 'To retrieve the contract, it must have the status of Complete', 'warning');
            return;
        }

        this.showSpinner = true;
        getContract({ contractId: this.recordId })
            .then(() => {
                this.showSpinner = false;
                this.toast('Success', 'Waiver file retrieved successfully', 'success');
                // Reload to reflect Files related list
                // eslint-disable-next-line no-restricted-globals
                location.reload();
            })
            .catch(error => {
                this.showSpinner = false;
                this.toast('Error', this.formatErrorString(error), 'error');
            });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
    }

    formatErrorString(errors) {
        let listOfErrors = this.getListOfErrors(errors);
        let errorMsg = '';
        for (let msg of listOfErrors) errorMsg += msg + ' ';
        return errorMsg;
    }

    getListOfErrors(errors) {
        if (!Array.isArray(errors)) errors = [errors];
        return (
            errors
                .filter((e) => !!e)
                .map((e) => {
                    if (Array.isArray(e.body)) return e.body.map((x) => x.message);
                    else if (e.body && typeof e.body.message === 'string') return e.body.message;
                    else if (typeof e.message === 'string') return e.message;
                    return e.statusText;
                })
                .reduce((prev, curr) => prev.concat(curr), [])
                .filter((m) => !!m)
        );
    }
}
