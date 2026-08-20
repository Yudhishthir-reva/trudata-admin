//
//  ExpenseServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class ExpenseServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    private var userId: String {
        UserDefaultManager.shared.getUserDefaultsString(key: .userId)
    }

    func fetchAllExpensesList() -> AnyPublisher<ExpenseListResponse, Error> {
        networkService.request(APIRouter.allExpensesList, params: [:], headers: authHeaders)
    }

    func updateExpenseStatus(
        expenseId: Int,
        status: String,
        staffId: String
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "id": expenseId,
            "status": status,
            "staff_id": staffId
        ]
        return networkService.request(APIRouter.updateExpenseStatus, params: params, headers: authHeaders)
    }

    func addExpense(
        expenseDate: String,
        amount: String,
        remark: String,
        imageData: Data?
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        var params: [String: Any] = [
            "staff_id": userId,
            "expense_date": expenseDate,
            "expense_amount": amount,
            "remark": remark
        ]

        var files: [MultipartFileUpload] = []
        if let imageData {
            files.append(
                MultipartFileUpload(
                    fieldName: "expense_image",
                    fileName: "\(userId)_expense_image.jpg",
                    mimeType: "image/jpeg",
                    data: imageData
                )
            )
        } else {
            params["expense_image"] = ""
        }

        return networkService.uploadMultipart(
            APIRouter.addExpense,
            params: params,
            file: files.first,
            files: files,
            headers: authHeaders
        )
    }
}
