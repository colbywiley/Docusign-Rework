<aura:application controller="DocusignConsentResultCtlr" access="global" extends="force:slds">
    <aura:attribute name="toast" type="Object" />
    <aura:attribute name="docusignSetting" type="Object" />
    <aura:attribute name="code" type="String" description="Code parameter is to be passed when consent is done successfully"/>
	<aura:handler name="init" value="{!this}" action="{!c.init}" />
	
	<div class="slds-align_absolute-center tr-docusign-container">
		<aura:if isTrue="{!v.code}">
			<div class="slds-text-heading_medium">
				You have successfully signed the consent.
			</div>
			<aura:set attribute="else">
				<div>
					<button class="slds-button slds-button_brand" onclick="{!c.requestConsent}">Request Consent</button>
					<button class="slds-button slds-button_brand slds-m-left_large" onclick="{!c.checkOAuth}">Check if OAuth works</button>
				</div>
			</aura:set>
		</aura:if>
		
	</div>

	<aura:if isTrue="{!v.toast}">
		<div class="slds-notify_container">
			<div class="{!v.toast.className}" role="status">
				<span class="slds-assistive-text">{!v.toast.type}</span>
				<div class="slds-notify__content">
					<h2 class="slds-text-heading_small ">{!v.toast.message}</h2>
				</div>
				<div class="slds-notify__close">
					<button class="slds-button slds-button_icon slds-button_icon-inverse" title="Close" onclick="{!c.hideToast}">
						<lightning:icon iconName="utility:close" size="x-small" alternativeText="Close" variant="inverse"/>
					</button>
				</div>
			</div>
		</div>
	</aura:if>
</aura:application>