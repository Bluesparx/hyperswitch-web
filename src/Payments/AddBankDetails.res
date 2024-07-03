module Loader = {
  @react.component
  let make = () => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div className="w-full flex items-center justify-center">
      <div className="w-8 h-8 animate-spin" style={color: themeObj.colorTextSecondary}>
        <Icon size=32 name="loader" />
      </div>
    </div>
  }
}

@react.component
let make = (~paymentMethodType) => {
  open Utils
  open Promise
  let {publishableKey, clientSecret, iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let setOptionValue = Recoil.useSetRecoilState(RecoilAtoms.optionAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let setShowFields = Recoil.useSetRecoilState(RecoilAtoms.showCardFieldsAtom)
  let (showLoader, setShowLoader) = React.useState(() => false)

  let pmAuthConnectorsArr =
    PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(
      paymentMethodListValue.payment_methods,
    )->PmAuthConnectorUtils.getAllRequiredPmAuthConnectors

  React.useEffect0(() => {
    let onPlaidCallback = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->getBool("isPlaid", false) {
        let publicToken = dict->getDictFromDict("data")->getString("publicToken", "")
        let isExited = dict->getDictFromDict("data")->getBool("isExited", false)
        setShowLoader(_ => !isExited)
        if publicToken->String.length > 0 {
          PaymentHelpers.callAuthExchange(
            ~publicToken,
            ~clientSecret,
            ~paymentMethodType,
            ~publishableKey,
            ~setOptionValue,
          )
          ->then(_ => {
            handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
            setShowFields(_ => false)
            JSON.Encode.null->resolve
          })
          ->catch(_ => JSON.Encode.null->resolve)
          ->ignore
        }
      }
    }

    Window.addEventListener("message", onPlaidCallback)
    Some(
      () => {
        Window.removeEventListener("message", ev => onPlaidCallback(ev))
      },
    )
  })

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message="Please add Bank Details and then confirm payment with the added payment methods.",
      )
    }
  }, [])
  useSubmitPaymentData(submitCallback)

  let onClickHandler = () => {
    setShowLoader(_ => true)
    PaymentHelpers.callAuthLink(
      ~publishableKey,
      ~clientSecret,
      ~iframeId,
      ~paymentMethodType,
      ~pmAuthConnectorsArr,
    )->ignore
  }

  <button
    onClick={_ => onClickHandler()}
    disabled={showLoader}
    style={
      width: "100%",
      padding: "20px",
      cursor: "pointer",
      borderRadius: themeObj.borderRadius,
      borderColor: themeObj.borderColor,
      borderWidth: "2px",
    }>
    {if showLoader {
      <Loader />
    } else {
      {React.string("Add Bank Details")}
    }}
  </button>
}