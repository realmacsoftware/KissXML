/**
 * Welcome to KissXML.
 * 
 * The project page has documentation if you have questions.
 * https://github.com/robbiehanson/KissXML
 * 
 * If you're new to the project you may wish to read the "Getting Started" wiki.
 * https://github.com/robbiehanson/KissXML/wiki/GettingStarted
 * 
 * KissXML provides a drop-in replacement for Apple's NSXML class cluster.
 * The goal is to get the exact same behavior as the NSXML classes.
 * 
 * For API Reference, see Apple's excellent documentation,
 * either via Xcode's Mac OS X documentation, or via the web:
 * 
 * https://github.com/robbiehanson/KissXML/wiki/Reference
**/

#import <Foundation/Foundation.h>

#import "KissXML/DDXMLNode.h"
#import "KissXML/DDXMLElement.h"

#import "KissXML/DDXMLDocument.h"
#import "KissXML/DDHTMLDocument.h"

#import "KissXML/DDXMLNode+DDAdditions.h"
#import "KissXML/DDXMLElement+DDAdditions.h"

#import "KissXML/KissXML-Constants.h"

#if TARGET_OS_IPHONE

// Since KissXML is a drop in replacement for NSXML,
// it may be desireable (when writing cross-platform code to be used on both Mac OS X and iOS)
// to use the NSXML prefixes instead of the DDXML prefix.
// 
// This way, on Mac OS X it uses NSXML, and on iOS it uses KissXML.

@compatibility_alias NSXMLNode DDXMLNode;

@compatibility_alias NSXMLElement DDXMLElement;

@compatibility_alias NSXMLDocument DDXMLDocument;

#if !defined(NSXMLInvalidKind)
	#define NSXMLInvalidKind DDXMLInvalidKind
#endif
#if !defined(NSXMLDocumentKind)
	#define NSXMLDocumentKind DDXMLDocumentKind
#endif
#if !defined(NSXMLElementKind)
	#define NSXMLElementKind DDXMLElementKind
#endif
#if !defined(NSXMLAttributeKind)
	#define NSXMLAttributeKind DDXMLAttributeKind
#endif
#if !defined(NSXMLNamespaceKind)
	#define NSXMLNamespaceKind DDXMLNamespaceKind
#endif
#if !defined(NSXMLProcessingInstructionKind)
	#define NSXMLProcessingInstructionKind DDXMLProcessingInstructionKind
#endif
#if !defined(NSXMLCommentKind)
	#define NSXMLCommentKind DDXMLCommentKind
#endif
#if !defined(NSXMLTextKind)
	#define NSXMLTextKind DDXMLTextKind
#endif
#if !defined(NSXMLDTDKind)
	#define NSXMLDTDKind DDXMLDTDKind
#endif
#if !defined(NSXMLEntityDeclarationKind)
	#define NSXMLEntityDeclarationKind DDXMLEntityDeclarationKind
#endif
#if !defined(NSXMLAttributeDeclarationKind)
	#define NSXMLAttributeDeclarationKind DDXMLAttributeDeclarationKind
#endif
#if !defined(NSXMLElementDeclarationKind)
	#define NSXMLElementDeclarationKind DDXMLElementDeclarationKind
#endif
#if !defined(NSXMLNotationDeclarationKind)
	#define NSXMLNotationDeclarationKind DDXMLNotationDeclarationKind
#endif

#if !defined(NSXMLNodeOptionsNone)
	#define NSXMLNodeOptionsNone DDXMLNodeOptionsNone
#endif
#if !defined(NSXMLNodeExpandEmptyElement)
	#define NSXMLNodeExpandEmptyElement DDXMLNodeExpandEmptyElement
#endif
#if !defined(NSXMLNodeCompactEmptyElement)
	#define NSXMLNodeCompactEmptyElement DDXMLNodeCompactEmptyElement
#endif
#if !defined(NSXMLNodePrettyPrint)
	#define NSXMLNodePrettyPrint DDXMLNodePrettyPrint
#endif

#endif /* TARGET_OS_IPHONE */
