//
//  WhiskyConfig.swift
//  WhiskyKit
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation

public enum WhiskyConfig {
    /// Base URL for self-hosted Wine distribution files (GitHub Releases).
    private static let baseURL = "https://github.com/chrisknu/Rye/releases/download/v2.5.0-wine"

    /// URL to the Wine libraries tarball downloaded during setup.
    public static let wineDownloadURL = "\(baseURL)/Libraries.tar.gz"

    /// URL to the Wine version plist used for update checks.
    public static let wineVersionURL = "\(baseURL)/WhiskyWineVersion.plist"
}
