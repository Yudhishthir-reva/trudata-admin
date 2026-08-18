//
//  APIRouter.swift
//  Truedata
//

enum APIRouter: RouterManagable {

    case loginUser
    case homeV2
    case logout
    case getRiderList
    case getBeatAssignOrderWise
    case vehicleList
    case getAssignOrderBeatWiseList
    case orderAssignSave
    case pendingBills
    case settlePendingBills
    case orderApprovalRequestList
    case updateOrderApprovalRequest
    case viewPendingPaymentBillList
    case orderDetail
    case orderListV2
    case orderListV3
    case staffList
    case sellerList2
    case getAllArea
    case sellerListBeatWise
    case setStaffBeat
    case beatWiseArrangeSellers
    case orderApprovalRequest
    case sellerProfile2
    case colorList
    case updateSellerColor
    case sellerOrderList
    case sellerTransactions
    case paymentSave
    case paymentBillList
    case paymentSettlement
    case brandList
    case topSellingProductsSuggestion
    case productSearchWiseList
    case addProductSpecialPrice

    var endPointUrl: String {
        switch self {
        case .loginUser:
            return "login-user"
        case .homeV2:
            return "V2/home3"
        case .logout:
            return "logout"
        case .getRiderList:
            return "get-rider-list"
        case .getBeatAssignOrderWise:
            return "get-beat-assign-order-wise"
        case .vehicleList:
            return "vehicle-list"
        case .getAssignOrderBeatWiseList:
            return "get-assign-order-beat-wise-list"
        case .orderAssignSave:
            return "order-assign-save"
        case .pendingBills:
            return "pending-bills"
        case .settlePendingBills:
            return "settle-pending-bills"
        case .orderApprovalRequestList:
            return "order-approval-request-list"
        case .updateOrderApprovalRequest:
            return "update-order-approval-request"
        case .viewPendingPaymentBillList:
            return "view-pending-payment-bill-list"
        case .orderDetail:
            return "order-detail"
        case .orderListV2:
            return "V2/order-list2"
        case .orderListV3:
            return "V2/order-list3"
        case .staffList:
            return "staff-list"
        case .sellerList2:
            return "seller-list2"
        case .getAllArea:
            return "get-all-data"
        case .sellerListBeatWise:
            return "seller-list-beat-wise2"
        case .setStaffBeat:
            return "set-staff-beat"
        case .beatWiseArrangeSellers:
            return "beat-wise-arrange-sellers"
        case .orderApprovalRequest:
            return "order-approval-request"
        case .sellerProfile2:
            return "seller-Profile2"
        case .colorList:
            return "color-list"
        case .updateSellerColor:
            return "update-seller-color"
        case .sellerOrderList:
            return "seller-order-list"
        case .sellerTransactions:
            return "seller-transactions"
        case .paymentSave:
            return "payment-save"
        case .paymentBillList:
            return "payment-bill-list"
        case .paymentSettlement:
            return "payment-settlement"
        case .brandList:
            return "brand-list"
        case .topSellingProductsSuggestion:
            return "V2/top-selling-products-suggestion"
        case .productSearchWiseList:
            return "product-search-wise-list"
        case .addProductSpecialPrice:
            return "add-product-special-price"
        }
    }

    var contentType: RequestContentType {
        switch self {
        case .updateSellerColor, .addProductSpecialPrice:
            return .json
        case .paymentSave, .paymentSettlement:
            return .multipartForm
        default:
            return .urlEncoded
        }
    }
}
