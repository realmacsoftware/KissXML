//
//  DDHTMLDocument.h
//  KissXML
//
//  Created by Damien DeVille on 21/11/2011.
//  Copyright (c) 2011 Realmac Software. All rights reserved.
//

#import "DDXMLDocument.h"

typedef NSUInteger DDHTMLDocumentParserOption;

extern DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseRecover;
extern DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoError;
extern DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoWarning;
extern DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParsePedantic;
extern DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoBlanks;
extern DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoNetwork;
extern DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseCompact;

@interface DDHTMLDocument : DDXMLDocument

- (id)initWithHTMLData:(NSData *)data options:(NSUInteger)options error:(NSError **)error;
- (id)initWithHTMLString:(NSString *)string options:(NSUInteger)options error:(NSError **)error;

@end
