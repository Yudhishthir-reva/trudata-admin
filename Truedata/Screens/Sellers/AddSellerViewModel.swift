//
//  AddSellerViewModel.swift
//  Truedata
//

import Foundation
import Combine
import UIKit

@MainActor
final class AddSellerViewModel: ObservableObject {

    let editSellerId: Int?

    @Published var sellerName = ""
    @Published var shopName = ""
    @Published var registeredByName = ""
    @Published var assignedToId: Int?
    @Published var assignedToName = ""
    @Published var mobile = ""
    @Published var whatsapp = ""
    @Published var email = ""
    @Published var gstNo = ""
    @Published var landmark = ""
    @Published var manualAddress = ""
    @Published var address = ""
    @Published var gpsLocation = "Fetching location..."
    @Published var stateId: Int?
    @Published var stateName = ""
    @Published var cityId: Int?
    @Published var cityName = ""
    @Published var beatId: Int?
    @Published var beatName = ""
    @Published var sellerTypeId: Int?
    @Published var sellerTypeName = ""
    @Published var profileImage: UIImage?
    @Published var aadharFrontImage: UIImage?
    @Published var aadharBackImage: UIImage?
    @Published var areas: [OrderInsightsStateArea] = []
    @Published var sellerTypes: [AddSellerTypeItem] = []
    @Published var staffMembers: [AddSellerStaffMember] = []
    @Published var isLoading = false
    @Published var isLoadingDetail = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var validationErrors = AddSellerFormErrors()
    @Published var showSuccessAlert = false
    @Published var successMessage = ""

    private let service: AddSellerServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var pendingDetail: SellerDetailData?

    var isEditMode: Bool { editSellerId != nil }

    var screenTitle: String {
        isEditMode ? "Edit Seller" : "Add New Seller"
    }

    init(
        editSellerId: Int? = nil,
        service: AddSellerServiceManager = AddSellerServiceManager()
    ) {
        self.editSellerId = editSellerId
        self.service = service
        registeredByName = UserDefaultManager.shared.getUserDefaultsString(key: .userName)
    }

    var availableCities: [OrderInsightsCityArea] {
        guard let stateId else { return [] }
        return areas.first(where: { $0.id == stateId })?.cities ?? []
    }

    var availableBeats: [OrderInsightsBeatArea] {
        guard let cityId else { return [] }
        return areas.flatMap(\.cities).first(where: { $0.id == cityId })?.beats ?? []
    }

    var selectableStaff: [AddSellerStaffMember] {
        staffMembers.filter { $0.roleId != "Rider" }
    }

    func loadInitialData(locationSnapshot: LocationSnapshot?) {
        if let locationSnapshot {
            gpsLocation = "\(locationSnapshot.latitude), \(locationSnapshot.longitude)"
            address = locationSnapshot.address
        }
        loadAreas()
        loadSellerTypes()
        loadStaff()
        if let editSellerId {
            loadSellerDetail(sellerId: editSellerId)
        }
    }

    func selectState(_ state: OrderInsightsStateArea) {
        stateId = state.id
        stateName = state.name
        cityId = nil
        cityName = ""
        beatId = nil
        beatName = ""
    }

    func selectCity(_ city: OrderInsightsCityArea) {
        cityId = city.id
        cityName = city.name
        beatId = nil
        beatName = ""
    }

    func selectBeat(_ beat: OrderInsightsBeatArea) {
        beatId = beat.id
        beatName = beat.name
    }

    func selectSellerType(_ type: AddSellerTypeItem) {
        sellerTypeId = type.id
        sellerTypeName = type.name
    }

    func selectStaff(_ staff: AddSellerStaffMember) {
        assignedToId = staff.id
        assignedToName = staff.name
    }

    func updateLocation(_ snapshot: LocationSnapshot) {
        gpsLocation = "\(snapshot.latitude), \(snapshot.longitude)"
        address = snapshot.address
    }

    func setPhoto(_ image: UIImage?, kind: AddSellerPhotoKind) {
        switch kind {
        case .profile: profileImage = image
        case .aadharFront: aadharFrontImage = image
        case .aadharBack: aadharBackImage = image
        }
    }

    func submit(locationSnapshot: LocationSnapshot?) {
        guard validate() else { return }
        isSubmitting = true
        errorMessage = nil

        let lat = locationSnapshot.map { String($0.latitude) } ?? gpsLocation.split(separator: ",").first.map(String.init) ?? "0.0"
        let long = locationSnapshot.map { String($0.longitude) } ?? gpsLocation.split(separator: ",").dropFirst().first.map { String($0.trimmingCharacters(in: .whitespaces)) } ?? "0.0"
        let resolvedAddress = locationSnapshot?.address ?? address

        if isEditMode {
            submitUpdate(lat: lat, long: long, address: resolvedAddress)
        } else {
            submitAdd(lat: lat, long: long, address: resolvedAddress)
        }
    }

    private func submitAdd(lat: String, long: String, address: String) {
        var params: [String: Any] = [
            "name": sellerName,
            "mobile": mobile,
            "email": email,
            "state": stateId ?? 0,
            "city": cityId ?? 0,
            "beat_id": beatId ?? 0,
            "shop_name": shopName,
            "whatsapp_no": whatsapp,
            "landmark": landmark,
            "latitude": lat,
            "longitude": long,
            "address": address,
            "manual_address": manualAddress,
            "seller_type": sellerTypeId ?? 0,
            "assign_to": assignedToId.map(String.init) ?? "",
            "gst_no": gstNo,
            "accuracy": "0.0",
            "app_location_drop_time": String(Int(Date().timeIntervalSince1970 * 1000))
        ]

        var files: [MultipartFileUpload] = []
        if let data = profileImage?.compressedJPEGData() {
            files.append(MultipartFileUpload(fieldName: "profile_pic", fileName: "profile_pic.jpg", mimeType: "image/jpeg", data: data))
        }
        if let data = aadharFrontImage?.compressedJPEGData() {
            files.append(MultipartFileUpload(fieldName: "aadhar_front_pic", fileName: "aadhar_front_pic.jpg", mimeType: "image/jpeg", data: data))
        }
        if let data = aadharBackImage?.compressedJPEGData() {
            files.append(MultipartFileUpload(fieldName: "aadhar_back_pic", fileName: "aadhar_back_pic.jpg", mimeType: "image/jpeg", data: data))
        }

        service.addSeller(params: params, files: files)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSubmitting = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.successMessage = "Seller added successfully."
                    self.showSuccessAlert = true
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Unable to add seller." : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func submitUpdate(lat: String, long: String, address: String) {
        guard let editSellerId else { return }
        let params: [String: Any] = [
            "seller_id": editSellerId,
            "name": sellerName,
            "mobile": mobile,
            "email": email,
            "state": stateId ?? 0,
            "city": cityId ?? 0,
            "beat_id": beatId ?? 0,
            "shop_name": shopName,
            "whatsapp_no": whatsapp,
            "landmark": landmark,
            "latitude": lat,
            "longitude": long,
            "address": address,
            "manual_address": manualAddress,
            "seller_type": sellerTypeId ?? 0,
            "assign_to": assignedToId.map(String.init) ?? "",
            "gst_no": gstNo
        ]

        service.updateSeller(params: params)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSubmitting = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.successMessage = "Seller updated successfully."
                    self.showSuccessAlert = true
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Unable to update seller." : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func validate() -> Bool {
        let gstRegex = try? NSRegularExpression(pattern: "^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$")
        let emailValid = email.isEmptyString || email.contains("@")
        let gstValid: Bool = {
            guard !gstNo.isEmptyString, let gstRegex else { return true }
            let range = NSRange(gstNo.startIndex..<gstNo.endIndex, in: gstNo)
            return gstRegex.firstMatch(in: gstNo, range: range) != nil
        }()

        validationErrors = AddSellerFormErrors(
            sellerName: sellerName.isEmptyString ? "Seller name cannot be empty" : nil,
            shopName: shopName.isEmptyString ? "Shop name cannot be empty" : nil,
            mobile: (10...11).contains(mobile.count) ? nil : "Enter a valid 10 or 11-digit number",
            email: emailValid ? nil : "Invalid email format",
            gstNo: gstValid ? nil : "Invalid GST number format",
            state: stateId == nil ? "State must be selected" : nil,
            city: cityId == nil ? "City must be selected" : nil,
            beat: beatId == nil ? "Beat must be selected" : nil,
            sellerType: sellerTypeId == nil ? "Seller Type must be selected" : nil,
            assignedTo: assignedToId == nil ? "Assigned to must be selected" : nil
        )
        return !validationErrors.hasErrors
    }

    private func loadAreas() {
        isLoading = true
        service.fetchAllAreas()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.areas = response.states
                if !self.isEditMode {
                    self.applyDefaultAreaSelection()
                } else if let pendingDetail = self.pendingDetail {
                    self.applyDetail(pendingDetail)
                }
            }
            .store(in: &cancellables)
    }

    private func applyDefaultAreaSelection() {
        guard let rajasthan = areas.first(where: { $0.name.uppercased() == "RAJASTHAN" }),
              let jaipur = rajasthan.cities.first(where: { $0.name.caseInsensitiveCompare("Jaipur") == .orderedSame }) else {
            return
        }
        selectState(rajasthan)
        selectCity(jaipur)
    }

    private func loadSellerTypes() {
        service.fetchSellerTypes()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                self?.sellerTypes = response.data
                if let detail = self?.pendingDetail {
                    self?.applyDetail(detail)
                }
            }
            .store(in: &cancellables)
    }

    private func loadStaff() {
        service.fetchStaffList()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                self?.staffMembers = response.data
                if let detail = self?.pendingDetail {
                    self?.applyDetail(detail)
                }
            }
            .store(in: &cancellables)
    }

    private func loadSellerDetail(sellerId: Int) {
        isLoadingDetail = true
        service.fetchSellerDetail(sellerId: sellerId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingDetail = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self, let detail = response.data else {
                    self?.errorMessage = response.message.isEmptyString ? "Unable to load seller details." : response.message
                    return
                }
                self.applyDetail(detail)
            }
            .store(in: &cancellables)
    }

    private func applyDetail(_ detail: SellerDetailData) {
        pendingDetail = detail
        guard !areas.isEmpty else { return }
        sellerName = detail.name
        shopName = detail.shopName
        mobile = detail.mobile
        whatsapp = detail.whatsappNo
        email = detail.email
        landmark = detail.landmark
        gstNo = detail.gstNo
        manualAddress = detail.manualAddress
        address = detail.address
        gpsLocation = "\(detail.latitude), \(detail.longitude)"
        registeredByName = detail.registeredByName.isEmptyString ? registeredByName : detail.registeredByName

        if let typeId = Int(detail.sellerTypeId),
           let type = sellerTypes.first(where: { $0.id == typeId }) {
            selectSellerType(type)
        } else if let type = sellerTypes.first(where: { String($0.id) == detail.sellerTypeId }) {
            selectSellerType(type)
        }

        if let staffId = Int(detail.assignTo),
           let staff = staffMembers.first(where: { $0.id == staffId }) {
            selectStaff(staff)
        } else if let staff = staffMembers.first(where: { $0.name == detail.assignToName }) {
            selectStaff(staff)
        }

        let resolvedState = areas.first {
            $0.name.caseInsensitiveCompare(detail.stateId) == .orderedSame
        }
        if let resolvedState {
            selectState(resolvedState)
            if let resolvedCity = resolvedState.cities.first(where: {
                $0.name.caseInsensitiveCompare(detail.cityId) == .orderedSame
            }) {
                selectCity(resolvedCity)
                if let beatNumericId = Int(detail.dbBeatId),
                   let beat = resolvedCity.beats.first(where: { $0.id == beatNumericId }) {
                    selectBeat(beat)
                } else if let beat = resolvedCity.beats.first(where: {
                    $0.name.caseInsensitiveCompare(detail.beatId) == .orderedSame
                }) {
                    selectBeat(beat)
                }
            }
        }
        pendingDetail = nil
    }
}
