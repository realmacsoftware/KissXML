//
//  DDXMLNode+DDAdditions.m
//  KissXML
//
//  Created by Keith Duncan on 07/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLNode+DDAdditions.h"

#import "KissXML-Constants.h"

@implementation DDXMLNode (DDAdditions)

- (DDXMLNode *)_rmfoundation_nodeForXPath:(NSString *)XPath namespaceMap:(NSDictionary *)namespaceMap error:(NSError **)errorRef {
	NSArray *nodes = [self nodesForXPath:XPath namespaceMap:namespaceMap error:errorRef];
	if (nodes == nil) {
		return nil;
	}
	
	DDXMLNode *node = [nodes lastObject];
	if ([nodes count] != 1) {
		if (errorRef != NULL) {
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   NSLocalizedStringFromTableInBundle(@"No such node", nil, [NSBundle bundleWithIdentifier:DDXMLBundleIdentifier], @"DDXMLNode+DDAdditions no such node error description"), NSLocalizedDescriptionKey,
									   XPath, @"DDXMLNode(DDAdditions)ErrorFailingXPathErrorKey",
									   nil];
			*errorRef = [NSError errorWithDomain:DDXMLBundleIdentifier code:DDXMLErrorCodeUnknown userInfo:errorInfo];
		}
		return nil;
	}
	
	return node;
}

- (NSString *)stringValueForXPath:(NSString *)XPath namespaceMap:(NSDictionary *)namespaceMap error:(NSError **)errorRef {
	DDXMLNode *node = [self _rmfoundation_nodeForXPath:XPath namespaceMap:namespaceMap error:errorRef];
	if (node == nil) {
		return nil;
	}
	
	NSString *stringValue = [node stringValue];
	if (stringValue == nil) {
		stringValue = @"";
	}
	return stringValue;
}

- (NSString *)XMLStringValueForXPath:(NSString *)XPath namespaceMap:(NSDictionary *)namespaceMap error:(NSError **)errorRef {
	DDXMLNode *node = [self _rmfoundation_nodeForXPath:XPath namespaceMap:namespaceMap error:errorRef];
	if (node == nil) {
		return nil;
	}
	
	NSString *XMLString = [node XMLString];
	if (XMLString == nil) {
		XMLString = @"";
	}
	return XMLString;
}

@end
