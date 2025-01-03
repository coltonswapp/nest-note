//
//  NestUser.swift
//  nest-note
//
//  Created by Colton Swapp on 11/2/24.
//

import Foundation

class NestUser: Codable {
    let id: String
    var personalInfo: PersonalInfo
    var primaryRole: UserType
    var roles: UserRoles

    init(id: String, personalInfo: PersonalInfo, primaryRole: UserType, roles: UserRoles) {
        self.id = id
        self.personalInfo = personalInfo
        self.primaryRole = primaryRole
        self.roles = roles
    }
    
    struct PersonalInfo: Codable {
        var name: String
        var email: String
        var phone: String?
    }
    
    struct UserRoles: Codable {
        var ownedNestId: String?    // If they own a nest
        var nestAccess: [NestAccess] // Nests they have access to
    }
    
    enum UserType: String, Codable {
        case nestOwner = "nester"  // Primary role is nest owner
        case sitter = "sitter"  // Primary role is sitter
    }
    
    struct NestAccess: Codable {
        let nestId: String
        var accessLevel: AccessLevel
        var nickname: String?  // How they reference this nest
        let grantedAt: Date
        
        enum AccessLevel: String, Codable {
            case owner = "owner"
            case executive = "executive"  // Grandparents, trusted family - full access except ownership transfer
            case sitter = "sitter"       // Basic sitter access during sessions
            case limited = "limited"      // Maybe a teenager helper who can only see basic info
        }
    }
}

extension NestUser: CustomStringConvertible {
    var description: String {
        """
        NestUser(
            id: \(id),
            name: \(personalInfo.name),
            email: \(personalInfo.email),
            phone: \(personalInfo.phone ?? "none"),
            ownsNest: \(roles.ownedNestId != nil),
            accessToNests: \(roles.nestAccess.count)
        )
        """
    }
}

// Optional: Add for nested structs as well
extension NestUser.PersonalInfo: CustomStringConvertible {
    var description: String {
        """
        PersonalInfo(
            name: \(name),
            email: \(email),
            phone: \(phone ?? "none")
        )
        """
    }
}

extension NestUser.UserRoles: CustomStringConvertible {
    var description: String {
        """
        UserRoles(
            ownedNestId: \(ownedNestId ?? "none"),
            nestAccess: \(nestAccess)
        )
        """
    }
}

extension NestUser.NestAccess: CustomStringConvertible {
    var description: String {
        """
        NestAccess(
            nestId: \(nestId),
            accessLevel: \(accessLevel),
            nickname: \(nickname ?? "none"),
            grantedAt: \(grantedAt)
        )
        """
    }
}
