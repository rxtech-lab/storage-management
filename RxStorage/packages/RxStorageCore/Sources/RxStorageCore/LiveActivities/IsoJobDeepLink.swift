//
//  IsoJobDeepLink.swift
//  RxStorageCore
//
//  rxstorage://iso-jobs/<id> links, opened when an ISO job's Live Activity is tapped
//

import Foundation

public enum IsoJobDeepLink {
    private static let scheme = "rxstorage"
    private static let host = "iso-jobs"

    public static func url(jobId: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(jobId)"
        return components.url!
    }

    /// The job ID in an ISO job link, or nil for any other URL
    public static func jobId(from url: URL) -> String? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        let id = url.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return id.isEmpty ? nil : id
    }
}
