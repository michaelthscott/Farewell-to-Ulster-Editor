//
//  MDPoem.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 28/07/2026.
//

import Foundation

struct MDPoem {
    let eraPaddedNumber: String
    let number: Int
    let title: String
    let text: String
    
    var paddedNumber: String {
        String(format: "%03d", number)
    }
    
    var path: String {
        "_Era\(eraPaddedNumber)/\(paddedNumber).md"
    }
    
    var markdownText: String {
        convertToMarkdown(text)
    }
    
    var markdown: String {
        """
---
layout: poem
title: \(title)
series: Era\(eraPaddedNumber)
---
\(markdownText)
"""
    }
    
    var data: Data {
        Data(markdown.utf8)
    }
}
