//
//  Supabase.swift
//  DinkLink
//
//  Created by Rabin, Dylan on 3/23/26.
//

import Foundation

enum SupabaseConfiguration {
    static let projectURL = URL(string: "https://nrygqwhhzizplpgnxvzk.supabase.co")!
    static let publishableKey = "sb_publishable_nIp2bN1lEk5620FvQVcV2g_afFh2Wvv"

    static var restURL: URL {
        projectURL.appending(path: "rest/v1")
    }

    static var authURL: URL {
        projectURL.appending(path: "auth/v1")
    }

    static let authSessionStorageKey = "supabase.auth.session"
}
