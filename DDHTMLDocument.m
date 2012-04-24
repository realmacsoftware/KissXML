//
//  DDHTMLDocument.m
//  KissXML
//
//  Created by Damien DeVille on 21/11/2011.
//  Copyright (c) 2011 Realmac Software. All rights reserved.
//

#import "DDHTMLDocument.h"

#import <libxml/HTMLparser.h>

#import "DDXMLDocument+Private.h"

#import "KissXML-Constants.h"

DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseRecover = HTML_PARSE_RECOVER;
DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoError = HTML_PARSE_NOERROR;
DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoWarning = HTML_PARSE_NOWARNING;
DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParsePedantic = HTML_PARSE_PEDANTIC;
DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoBlanks = HTML_PARSE_NOBLANKS;
DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseNoNetwork = HTML_PARSE_NONET;
DDHTMLDocumentParserOption DDHTMLDocumentParserOptionParseCompact = HTML_PARSE_COMPACT;

@implementation DDHTMLDocument

- (id)initWithHTMLData:(NSData *)data options:(NSUInteger)options error:(NSError **)errorRef
{
	if (data == nil || [data length] == 0) {
		if (errorRef != NULL) {
			*errorRef = [NSError errorWithDomain:DDXMLBundleIdentifier code:DDXMLErrorCodeUnknown userInfo:nil];
		}
		[self release];
		return nil;
	}
	
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
    xmlKeepBlanksDefault(0);
	
	xmlDocPtr document = htmlReadMemory([data bytes], [data length], "", NULL, options);
	if (document == NULL) {
		if (errorRef != NULL) {
			*errorRef = [NSError errorWithDomain:DDXMLBundleIdentifier code:DDXMLErrorCodeUnknown userInfo:nil];
		}
		
		[self release];
		return nil;
	}
	
	return [self initWithDocPrimitive: document owner: nil];
}

- (id)initWithHTMLString:(NSString *)string options:(NSUInteger)options error:(NSError **)errorRef
{
	return [self initWithHTMLData:[string dataUsingEncoding:[string fastestEncoding]] options:options error:errorRef];
}

@end
