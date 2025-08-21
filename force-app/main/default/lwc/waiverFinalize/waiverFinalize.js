import { LightningElement, track } from 'lwc';
import finalizeByWaiver from '@salesforce/apex/SmartwaiverFinalizeController.finalizeByWaiver';

export default class WaiverFinalize extends LightningElement {
  @track message = 'Please wait while we update your record...';

  connectedCallback() {
    const params = new URLSearchParams(window.location.search);
    const waiverId = params.get('waiverid') || params.get('waiverId');
    const autoTag  = params.get('autotag') || params.get('auto_tag');

    finalizeByWaiver({ waiverId, autoTagFromQuery: autoTag })
      .then(res => {
        if (res && res.success) {
          this.message = 'All set! You can close this window.';
          // Let the opener know immediately (so your launcher LWC can refresh)
          try {
            if (window.opener && !window.opener.closed) {
              window.opener.postMessage(
                { type: 'smartwaiver:complete', contractId: res.contractId }, '*'
              );
            }
          } catch (e) { /* ignore cross-window errors */ }
          // Optionally close after a short delay
          setTimeout(() => { window.close(); }, 1200);
        } else {
          this.message = 'We could not finalize the waiver: ' + (res ? res.message : 'Unknown error');
        }
      })
      .catch(err => {
        this.message = 'Error: ' + (err?.body?.message || err?.message || 'Unknown');
      });
  }
}
