/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

NS_ASSUME_NONNULL_BEGIN

NSStringEncoding const TXDefaultPrimaryStringEncoding = NSUTF8StringEncoding;
NSStringEncoding const TXDefaultFallbackStringEncoding = NSISOLatin1StringEncoding;

@implementation NSString (TXStringHelper)

- (BOOL)isValidInternetAddress
{
	if (self.length == 0) {
		return NO;
	}

	if (self.isIPAddress || NSObjectsAreEqual(self, @"localhost")) {
		return YES;
	}

	return [self onlyContainsCharacters:
		@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"];
}

- (BOOL)isValidInternetPort
{
	if (self.length == 0) {
		return NO;
	}

	if (self.isNumericOnly == NO) {
		return NO;
	}

	NSInteger selfInt = self.integerValue;

	return (selfInt > 0 && selfInt <= TXMaximumTCPPort);
}

- (NSString *)stringByAppendingIRCFormattingStop
{
	return [self stringByAppendingFormat:@"%C", IRCTextFormatterTerminatingCharacter];
}

- (BOOL)hostmaskComponents:(NSString * _Nullable * _Nullable)nickname username:(NSString * _Nullable * _Nullable)username address:(NSString * _Nullable * _Nullable)address
{
	return [self hostmaskComponents:nickname username:username address:address onClient:nil];
}

- (BOOL)hostmaskComponents:(NSString * _Nullable * _Nullable)nickname username:(NSString * _Nullable * _Nullable)username address:(NSString * _Nullable * _Nullable)address onClient:(nullable IRCClient *)client
{
	/* Find first ! starting from left side of string */
	NSRange bang1pos = [self rangeOfString:@"!" options:0];

	/* Find first @ starting from the right side of string */
	NSRange bang2pos = [self rangeOfString:@"@" options:NSBackwardsSearch];

	if ((bang1pos.location == NSNotFound) ||
		(bang2pos.location == NSNotFound) ||
		(bang2pos.location <= bang1pos.location))
	{
		return NO;
	}

	NSString *nicknameInt = [self substringToIndex:bang1pos.location];

	NSString *usernameInt = [self substringWithRange:
							 NSMakeRange((bang1pos.location + 1),
										 (bang2pos.location - (bang1pos.location + 1)))];

	NSString *addressInt = [self substringAfterIndex:bang2pos.location];

	if ([nicknameInt isHostmaskNicknameOn:client] == NO ||
		[usernameInt isHostmaskUsernameOn:client] == NO ||
		[addressInt isHostmaskAddressOn:client] == NO)
	{
		return NO;
	}

	if ( nickname) {
		*nickname = nicknameInt;
	}

	if ( username) {
		*username = usernameInt;
	}

	if ( address) {
		*address = addressInt;
	}

	return YES;
}

- (BOOL)isHostmask
{
	return [self hostmaskComponents:nil username:nil address:nil];
}

- (BOOL)isHostmaskAddress
{
	return [self isHostmaskAddressOn:nil];
}

- (BOOL)isHostmaskAddressOn:(IRCClient *)client
{
	return (self.length > 0 &&
			[self containsCharacters:@"\x021\x040\x000\x020\x00d\x00a"] == NO);
}

- (BOOL)isHostmaskUsername
{
	return [self isHostmaskUsernameOn:nil];
}

- (BOOL)isHostmaskUsernameOn:(IRCClient *)client
{
	return (self.length > 0 &&
			self.length <= TXMaximumIRCUsernameLength &&
			[self containsCharacters:@"\x000\x020\x00d\x00a"] == NO);
}

- (BOOL)isHostmaskNickname
{
	return [self isHostmaskNicknameOn:nil];
}

- (BOOL)isHostmaskNicknameOn:(IRCClient *)client
{
	NSUInteger maximumLength = TXMaximumIRCNicknameLength;

	if (client) {
		/* At least one server has been found (gitter.im) has been found
		 which does not send a configuration profile. They allow a 
		 nickname length larger than IRCISupportInfo uses as a default
		 which means parsing will go wonky. */
		/* A smarter workaround would probably to check if specific 
		 configuration options were received (e.g. "NICKLEN"), but that 
		 has more overhead than using a boolean. */

		if (client.supportInfo.configurationReceived) {
			maximumLength = client.supportInfo.maximumNicknameLength;
		} else {
			maximumLength = 0;
		}

		/* If we are connected to ZNC, then do not enforce maximum 
		 nickname length. It is easier to disable this check than
		 to check whether a nickname (e.g. *buffextras) should be
		 handled differently. */
		if (client.isConnectedToZNC) {
			maximumLength = 0;
		}
	}

	if (maximumLength == 0) {
		maximumLength = TXMaximumIRCNicknameLength;
	}

	return ([self isNotEqualTo:@"*"] &&
			self.length > 0 &&
			self.length <= maximumLength &&
			[self containsCharacters:@"\x021\x040\x000\x020\x00d\x00a"] == NO);
}

- (BOOL)isNickname
{
	return self.isHostmaskNickname;
}

- (BOOL)isChannelNameOn:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if (self.length == 0) {
		return NO;
	}

	NSArray *channelNamePrefixes = client.supportInfo.channelNamePrefixes;

	if (self.length == 1) {
		NSString *character = [self stringCharacterAtIndex:0];

		return [channelNamePrefixes containsObject:character];
	}

	NSString *character1 = [self stringCharacterAtIndex:0];
	NSString *character2 = [self stringCharacterAtIndex:1];
		
	/* The ~ prefix is considered special. It is used by the ZNC partyline plugin. */
	BOOL isPartyline = ([character1 isEqualToString:@"~"] && [character2 isEqualToString:@"#"]);

	return (isPartyline || [channelNamePrefixes containsObject:character1]);
}

- (BOOL)isChannelName
{
	if (self.length == 0) {
		return NO;
	}

	UniChar c = [self characterAtIndex:0];

	return (c == '#' ||
		    c == '&' ||
		    c == '+' ||
		    c == '!' ||
		    c == '~' ||
			c == '?');
}

- (nullable NSString *)channelNameWithoutBang
{
	if (self.isChannelName == NO) {
		return self;
	}

	return [self substringFromIndex:1];
}

- (nullable NSString *)channelNameWithoutBangOn:(IRCClient *)client
{
	NSParameterAssert(client != nil);

	if ([self isChannelNameOn:client] == NO) {
		return self;
	}

	if (self.length < 2) { // Do not turn "#" into empty string
		return self;
	}

	NSArray *channelNamePrefixes = client.supportInfo.channelNamePrefixes;

	NSString *character = [self stringCharacterAtIndex:0];

	if ([channelNamePrefixes containsObject:character]) {
		return [self substringFromIndex:1];
	}

	return self;
}

- (nullable NSString *)nicknameFromHostmask
{
	NSString *nickname = nil;

	if ([self hostmaskComponents:&nickname username:nil address:nil]) {
		return nickname;
	}

	return self;
}

- (nullable NSString *)usernameFromHostmask
{
	NSString *username = nil;

	if ([self hostmaskComponents:nil username:&username address:nil]) {
		return username;
	}

	return nil;
}

- (nullable NSString *)addressFromHostmask
{
	NSString *address = nil;

	if ([self hostmaskComponents:nil username:nil address:&address]) {
		return address;
	}

	return nil;
}

- (nullable NSString *)stringWithValidURIScheme
{
	return [AHHyperlinkScanner URLWithProperScheme:self];
}

- (nullable NSAttributedString *)attributedStringWithIRCFormatting:(NSFont *)preferredFont preferredFontColor:(nullable NSColor *)preferredFontColor honorFormattingPreference:(BOOL)formattingPreference
{
	if (formattingPreference && [TPCPreferences removeAllFormatting]) {
		NSString *string = self.stripIRCEffects;

		return [NSAttributedString attributedStringWithString:string];
	}

	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

	if (preferredFont) {
		attributes[TVCLogRendererConfigurationAttributedStringPreferredFontAttribute] = preferredFont;
	}

	if (preferredFontColor) {
		attributes[TVCLogRendererConfigurationAttributedStringPreferredFontColorAttribute] = preferredFontColor;
	}

	return [TVCLogRenderer renderBodyAsAttributedString:self withAttributes:attributes];
}

- (nullable NSAttributedString *)attributedStringWithIRCFormatting:(NSFont *)preferredFont preferredFontColor:(nullable NSColor *)preferredFontColor
{
	return [self attributedStringWithIRCFormatting:preferredFont preferredFontColor:preferredFontColor honorFormattingPreference:NO];
}

- (NSString *)stripIRCEffects
{
	NSUInteger stringLength = self.length;

	if (stringLength == 0) {
		return self;
	}

	NSUInteger currentPosition = 0;

	NSUInteger bufferLength = (stringLength * sizeof(UniChar));

	UniChar *inputBuffer = alloca(bufferLength);
	UniChar *outputBuffer = alloca(bufferLength);

	[self getCharacters:inputBuffer range:self.range];

	for (NSUInteger i = 0; i < stringLength; i++) {
		UniChar character = inputBuffer[i];

		switch (character) {
			case IRCTextFormatterBoldEffectCharacter:
			case IRCTextFormatterItalicEffectCharacter:
			case IRCTextFormatterItalicEffectCharacterOld:
			case IRCTextFormatterStrikethroughEffectCharacter:
			case IRCTextFormatterUnderlineEffectCharacter:
			case IRCTextFormatterTerminatingCharacter:
			{
				break;
			}
			case IRCTextFormatterColorEffectCharacter:
			{
				i += [self colorCodesStartingAt:i foregroundColor:NULL backgroundColor:NULL];

				break;
			}
			default:
			{
				outputBuffer[currentPosition++] = character;

				break;
			}
		}
	}

	return [NSString stringWithCharacters:outputBuffer length:currentPosition];
}

- (NSUInteger)colorCodesStartingAt:(NSUInteger)rangeStart foregroundColor:(NSUInteger *)foregroundColor backgroundColor:(NSUInteger *)backgroundColor
{
	NSUInteger selfLength = self.length;

	NSParameterAssert(rangeStart < selfLength);

	NSUInteger currentPosition = rangeStart;

	NSUInteger m_foregoundColor = NSNotFound;
	NSUInteger m_backgroundColor = NSNotFound;

	// ========================================== //

	if ((currentPosition + 1) >= selfLength) {
		goto return_method;
	}

	UniChar a = [self characterAtIndex:(currentPosition + 1)];

	if (CS_StringIsBase10Numeric(a) == NO) {
		goto return_method;
	}

	m_foregoundColor = (a - '0');

	currentPosition++;

	// ========================================== //

	if ((currentPosition + 1) >= selfLength) {
		goto return_method;
	}

	UniChar b = [self characterAtIndex:(currentPosition + 1)];

	if (CS_StringIsBase10Numeric(b) == NO && b != ',' ) {
		goto return_method;
	}

	currentPosition++;

	// ========================================== //

	if (b != ',') { // Eat up comma if /b/ is a number
		m_foregoundColor = (m_foregoundColor * 10 + b - '0');

		if ((currentPosition + 1) >= selfLength) {
			goto return_method;
		}

		UniChar c = [self characterAtIndex:(currentPosition + 1)];

		if (c != ',') {
			goto return_method;
		}

		currentPosition++;
	}

	// ========================================== //

	/* Minus index by 1 to allow trailing comma to appear
	 in the string incase a user configured a foreground
	 color without background but still had a comma. */
	if ((currentPosition + 1) >= selfLength) {
		currentPosition--;

		goto return_method;
	}

	UniChar d = [self characterAtIndex:(currentPosition + 1)];

	if (CS_StringIsBase10Numeric(d) == NO) {
		currentPosition--;

		goto return_method;
	}

	m_backgroundColor = (d - '0');

	currentPosition++;

	// ========================================== //

	if ((currentPosition + 1) >= selfLength) {
		goto return_method;
	}

	UniChar e = [self characterAtIndex:(currentPosition + 1)];

	if (CS_StringIsBase10Numeric(e) == NO) {
		goto return_method;
	}

	m_backgroundColor = (m_backgroundColor * 10 + e - '0');

	currentPosition++;

	// ========================================== //

return_method:
	if ( foregroundColor) {
		*foregroundColor = m_foregoundColor;
	}

	if ( backgroundColor) {
		*backgroundColor = m_backgroundColor;
	}

	return (currentPosition - rangeStart);
}

- (NSArray<NSString *> *)base64EncodingWithLineLength:(NSUInteger)lineLength
{
	NSData *selfData = [self dataUsingEncoding:NSUTF8StringEncoding];

	NSString *encodedString = [XRBase64Encoding encodeData:selfData];

	return [encodedString splitWithMaximumLength:lineLength];
}

- (nullable NSString *)padNicknameWithCharacter:(UniChar)padCharacter maximumLength:(NSUInteger)maximumLength
{
	NSParameterAssert(padCharacter != 0);
	NSParameterAssert(maximumLength > 0);

	NSString *padCharacterString = [NSString stringWithUniChar:padCharacter];

	if (self.length < maximumLength) {
		return [self stringByAppendingString:padCharacterString];
	}

	NSString *substring = [self substringToIndex:maximumLength];

	for (NSInteger i = (substring.length - 1); i >= 0; i--) {
		UniChar subsringCharacter = [substring characterAtIndex:i];

		if (subsringCharacter == padCharacter) {
			continue;
		}

		NSString *stringHead = [substring substringToIndex:i];

		NSMutableString *stringHeadMutable = [stringHead mutableCopy];

		for (NSUInteger j = i; j < substring.length; j++) {
			[stringHeadMutable appendString:@"_"];
		}

		return [stringHeadMutable copy];
	}

	return nil;
}

@end

NS_ASSUME_NONNULL_END
