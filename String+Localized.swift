//
//  String+Localized.swift
//  ffortes-EW-pratice
//
//  Created by Francisco Fortes on 15/11/2020.
//  Copyright © 2020 Francisco Fortes. All rights reserved.
//

import Foundation

extension String {
 
    var localized: String {
        let value = NSLocalizedString(self, comment: "")
        if value != self || NSLocale.preferredLanguages.first == "en" {
            return value
        }
        //The python script and Smartcat leave empty values if not translated. We need to fallback to english default:
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
            let bundle = Bundle(path: path) else { 
            return value 
        }
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
}
