//
//  AddStaffViewModel.swift
//  Truedata
//

import Foundation
import Combine
import UIKit

@MainActor
final class AddStaffViewModel: ObservableObject {

    let editStaffId: Int?

    @Published var name = ""
    @Published var mobile = ""
    @Published var email = ""
    @Published var stateId: Int?
    @Published var stateName = ""
    @Published var cityId: Int?
    @Published var cityName = ""
    @Published var roleId: Int?
    @Published var roleName = ""
    @Published var joiningDate = ""
    @Published var profileImage: UIImage?
    @Published var aadharFrontImage: UIImage?
    @Published var aadharBackImage: UIImage?
    @Published var areas: [OrderInsightsStateArea] = []
    @Published var roles: [StaffRoleItem] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var validationErrors = StaffFormErrors()
    @Published var showSuccessAlert = false
    @Published var successMessage = ""

    private let service = StaffServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var pendingEditMember: RegisteredStaffMember?

    var isEditMode: Bool { editStaffId != nil }

    var screenTitle: String {
        isEditMode ? "Edit Staff Member" : "Add New Staff Member"
    }

    var availableCities: [OrderInsightsCityArea] {
        guard let stateId else { return [] }
        return areas.first(where: { $0.id == stateId })?.cities ?? []
    }

    init(editStaffId: Int? = nil, editMember: RegisteredStaffMember? = nil) {
        self.editStaffId = editStaffId
        self.pendingEditMember = editMember
    }

    func loadInitialData() {
        isLoading = true
        errorMessage = nil

        Publishers.Zip(service.fetchAllAreas(), service.fetchRoles())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] areasResponse, rolesResponse in
                guard let self else { return }
                self.isLoading = false
                self.areas = areasResponse.states
                self.roles = rolesResponse.data

                if let member = self.pendingEditMember {
                    self.applyMember(member)
                } else if !self.isEditMode {
                    self.applyDefaultAreaSelection()
                    self.joiningDate = DashboardDateFormat.todayString
                } else {
                    self.loadMemberFromList()
                }
            }
            .store(in: &cancellables)
    }

    func selectState(_ state: OrderInsightsStateArea) {
        stateId = state.id
        stateName = state.name
        cityId = nil
        cityName = ""
    }

    func selectCity(_ city: OrderInsightsCityArea) {
        cityId = city.id
        cityName = city.name
    }

    func selectRole(_ role: StaffRoleItem) {
        roleId = role.id
        roleName = role.name
    }

    func setPhoto(_ image: UIImage?, kind: StaffPhotoKind) {
        switch kind {
        case .profile: profileImage = image
        case .aadharFront: aadharFrontImage = image
        case .aadharBack: aadharBackImage = image
        }
    }

    func submit() {
        guard validate() else { return }
        isSubmitting = true
        errorMessage = nil

        if isEditMode {
            submitUpdate()
        } else {
            submitAdd()
        }
    }

    private func submitAdd() {
        var params: [String: Any] = [
            "name": name,
            "mobile": mobile,
            "email": email,
            "state": stateId ?? 0,
            "city": cityId ?? 0,
            "role": roleId ?? -1,
            "joining_date": joiningDate
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

        service.addStaff(params: params, files: files)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSubmitting = false
                if case .failure(let error) = completion {
                    self?.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.successMessage = "Staff member added successfully."
                    self.showSuccessAlert = true
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Unable to add staff member." : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func submitUpdate() {
        guard let editStaffId else { return }
        let params: [String: Any] = [
            "staff_id": pendingEditMember?.staffId.nilIfEmpty ?? String(editStaffId),
            "name": name,
            "mobile": mobile,
            "email": email,
            "state": stateId ?? 0,
            "city": cityId ?? 0,
            "role": roleId ?? -1,
            "joining_date": joiningDate
        ]

        service.updateStaff(params: params)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSubmitting = false
                if case .failure(let error) = completion {
                    self?.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.successMessage = "Staff member updated successfully."
                    self.showSuccessAlert = true
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Unable to update staff member." : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func loadMemberFromList() {
        guard let editStaffId else { return }
        service.fetchStaffList()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self, let member = response.data.first(where: { $0.id == editStaffId }) else { return }
                self.applyMember(member)
            }
            .store(in: &cancellables)
    }

    private func applyMember(_ member: RegisteredStaffMember) {
        pendingEditMember = member
        name = member.name
        mobile = member.mobile
        email = member.email
        joiningDate = member.joiningDate
        roleName = member.roleId
        roleId = roles.first(where: { $0.name.caseInsensitiveCompare(member.roleId) == .orderedSame })?.id

        if let state = areas.first(where: {
            $0.name.caseInsensitiveCompare(member.stateId) == .orderedSame
                || String($0.id) == member.stateId
        }) {
            selectState(state)
            if let city = state.cities.first(where: {
                $0.name.caseInsensitiveCompare(member.cityId) == .orderedSame
                    || String($0.id) == member.cityId
            }) {
                selectCity(city)
            }
        }
    }

    private func applyDefaultAreaSelection() {
        guard let rajasthan = areas.first(where: { $0.name.uppercased() == "RAJASTHAN" }),
              let jaipur = rajasthan.cities.first(where: { $0.name.caseInsensitiveCompare("Jaipur") == .orderedSame }) else {
            return
        }
        selectState(rajasthan)
        selectCity(jaipur)
    }

    private func validate() -> Bool {
        validationErrors = StaffFormErrors(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Name cannot be empty" : nil,
            phone: mobile.count < 10 ? "Invalid phone number" : nil,
            state: stateId == nil ? "State must be selected" : nil,
            city: cityId == nil ? "City must be selected" : nil,
            role: roleId == nil ? "Role must be selected" : nil,
            joiningDate: joiningDate.isEmptyString ? "Joining date is required" : nil
        )
        return !validationErrors.hasErrors
    }
}
