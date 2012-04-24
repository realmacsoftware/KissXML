//
//  DDXMLInvalidNode.m
//  KissXML
//
//  Created by Keith Duncan on 14/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLInvalidNode.h"

@implementation DDXMLInvalidNode

// #pragma mark Properties

- (DDXMLNodeKind)kind {
	return DDXMLInvalidKind;
}

- (void)setName:(NSString *)name { }
- (NSString *)name {
	return nil;
}

- (void)setObjectValue:(id)value { }
- (id)objectValue {
	return nil;
}

- (void)setStringValue:(NSString *)string { }
- (void)setStringValue:(NSString *)string resolvingEntities:(BOOL)resolve { }
- (NSString *)stringValue {
	return nil;
}

// #pragma mark Tree Navigation

- (NSUInteger)index {
	return 0;
}

- (NSUInteger)level {
	return 0;
}

- (DDXMLDocument *)rootDocument {
	return nil;
}

- (DDXMLNode *)parent {
	return nil;
}
- (NSUInteger)childCount {
	return 0;
}
- (NSArray *)children {
	return [NSArray array];
}
- (DDXMLNode *)childAtIndex:(NSUInteger)idx {
	return nil;
}

- (DDXMLNode *)previousSibling {
	return nil;
}
- (DDXMLNode *)nextSibling {
	return nil;
}

- (DDXMLNode *)previousNode {
	return nil;
}
- (DDXMLNode *)nextNode {
	return nil;
}

- (void)detach { }

- (NSString *)XPath {
	return @"";
}

// #pragma mark QNames

- (NSString *)localName {
	return nil;
}
- (NSString *)prefix {
	return @"";
}

- (void)setURI:(NSString *)URI { }
- (NSString *)URI {
	return nil;
}

// #pragma mark Output

- (NSString *)description {
	return @"";
}
- (NSString *)XMLString {
	return @"";
}
- (NSString *)XMLStringWithOptions:(NSUInteger)options {
	return @"";
}
- (NSString *)canonicalXMLStringPreservingComments:(BOOL)comments {
	return nil;
}

// #pragma mark XPath/XQuery

- (NSArray *)nodesForXPath:(NSString *)xpath error:(NSError **)error {
	return [NSArray array];
}

- (NSArray *)objectsForXQuery:(NSString *)xquery constants:(NSDictionary *)constants error:(NSError **)error {
	return [NSArray array];
}
- (NSArray *)objectsForXQuery:(NSString *)xquery error:(NSError **)error {
	return [NSArray array];
}

@end
