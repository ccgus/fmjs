
# FMJS Privacy Practices

<style>
html {
	font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
	font-size: 106.25%;
}

body {
	font-size: 14px;
	line-height: 1.47059;
	font-weight: 400;
	letter-spacing: -.022em;
	font-family: "Helvetica Neue", "Helvetica", "Arial", sans-serif;
	background-color: #fff;
	color: #1d1d1f;
	font-style: normal;
	text-align: left;
	-webkit-font-smoothing: antialiased;
}

article {
	padding-top: 2em;
	padding-bottom: 2em;
}

main {
	overflow: auto;
}

section {
	padding-bottom: 2em;
}

h1 {
	margin-top: 0;
}

h1,
h2 {
	font-size: 32px;
	line-height: 1.125;
	font-weight: 600;
	letter-spacing: .004em;
}

h2 {
	margin-top: 1.6em;
	font-size: 24px;
	line-height: 1.16667;
	font-weight: 600;
	letter-spacing: .009em;
}

h3 {
	font-size: 19px;
	line-height: 1.21053;
	font-weight: 600;
	letter-spacing: .012em;
}

h4 {
	font-size: 12px;
	font-weight: 600;
	margin-top: 0;
	margin-bottom: 0;
}

p {
	margin-top: 0;
}

*+p {
	margin-top: 0.8em;
}

h4+p {
	margin-top: 0;
}

ol {
	margin-left: 0;
	padding-left: 1em;
}

ul {
	margin-left: 0;
	padding-left: 1em;
}

ul.alt li {
	list-style-type: circle;
}

table {
	margin: 0;
	text-align: left;
	border: 1px solid #ccc;
	border-collapse: collapse;
	border-spacing: 0;
	max-width: 730px;
}

table tr {
	border-bottom: 1px solid #ccc;
}

table tr th {
	background-color: #eaeaea;
	padding: 0.5em 10px;
	font-size: 14px;
	font-weight: 600;
}

table tr td {
	padding: 1em 10px;
	text-align: left;
	vertical-align: top;
}

table tr td:first-of-type {
	width: 50%;
	border-right: 1px solid #ccc;
}

table p {
	margin-bottom: 0;
}

table#sdk ul {
	margin-top: 0;
	margin-bottom: 0;
}

table#definitions tr:nth-of-type(even) td {
	background-color: #f6f6f6;
}

table#definitions tr td:first-of-type {
	width: 50%;
}

.section-content {
	width: 1120px;
}

.row {
	display: flex;
	flex-wrap: wrap;
	flex-direction: row;
}

.row-full {
	display: flex;
	flex-wrap: wrap;
	flex-direction: row;
	width: 100%;
}

.column {
	box-sizing: border-box;
	margin: 0;
	padding: 0;
	min-width: 0px;
	position: relative;
	flex-basis: 100%;
	max-width: 100%;
	width: 100%;
}

.column-split:first-of-type {
	flex-basis: 48%;
	max-width: 498px;
	width: 498px;
}

.column-split:last-of-type {
	flex-basis: 52%;
	max-width: 610px;
	width: 610px;
}

.sidebar {
	padding-left: 5em;
}

.sidebar h3 {
	margin-top: 0;
}

.sidebar ol li {
	padding-bottom: 2em;
}

.sidebar ol li:last-of-type {
	padding-bottom: 0;
}

.sidebar ol ul li {
	padding-bottom: 0.5em;
	list-style-type: disc;
}

.sidebar ol ul li:last-of-type {
	padding-bottom: 0;
}

.category-icon {
	display: inline-block;
	vertical-align: middle;
	margin: 0 10px 0 0;
	width: 24px;
	height: 24px;
	background-size: 100% 100%;
	background-repeat: no-repeat;
	background-position: center center;
}

.icon-browsing-history {
	background-image: url("images/browsing-history.svg");
}

.icon-contact-info {
	background-image: url("images/contact-info.svg");
}

.icon-contacts {
	background-image: url("images/contacts.svg");
}

.icon-diagnostics {
	background-image: url("images/diagnostics.svg");
}

.icon-financial-info {
	background-image: url("images/financial-info.svg");
}

.icon-health-info {
	background-image: url("images/health-info.svg");
}

.icon-identifiers {
	background-image: url("images/identifiers.svg");
}

.icon-linked {
	background-image: url("images/linked.svg");
}

.icon-location {
	background-image: url("images/location.svg");
}

.icon-not-linked {
	background-image: url("images/not-linked.svg");
}

.icon-other-data {
	background-image: url("images/other-data.svg");
}

.icon-purchase-history {
	background-image: url("images/purchase-history.svg");
}

.icon-search-history {
	background-image: url("images/search-history.svg");
}

.icon-sensitive-info {
	background-image: url("images/sensitive-info.svg");
}

.icon-track-you {
	background-image: url("images/track-you.svg");
}

.icon-usage-data {
	background-image: url("images/usage-data.svg");
}

.icon-user-content {
	background-image: url("images/user-content.svg");
}
</style>

## Contact Info

<table id="definitions" class="definitions">
<tbody>
<tr>
<th colspan="2">
<figure class="category-icon icon-contact-info"></figure>
Contact Info
</th>
</tr>
<tr>
<td><strong>Name</strong><br>Such as first or last name</td>
<td><li class="example">Does not collect data</li></td>
</tr>
<tr>
<td><strong>Email Address</strong><br>Including but not limited to a hashed email address</td>
<td>
<ul>
<li>Does not collect data</li>
<ul>
</td>
</tr>
<tr>
<td><strong>Phone Number</strong><br>Including but not limited to a hashed phone number											</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Physical Address</strong><br>Such as home address, physical address, or mailing address</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Other User Contact Info</strong><br>Any other information that can be used to contact the user outside the app</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-health-info"></figure>
Health and Fitness
</th>
</tr>
<tr>
<td><strong>Health</strong><br>Health and medical data, including but not limited to from the Clinical Health Records API, HealthKit API, MovementDisorderAPIs, or health-related human subject research or any other user provided health or medical data</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Fitness</strong><br>Fitness and exercise data, including but not limited to the Motion and Fitness API</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-financial-info"></figure>
Financial Info
</th>
</tr>
<tr>
<td><strong>Payment Info</strong><br>Such as form of payment, payment card number, or bank account number. If your app uses a payment service, the payment information is entered outside your app, and you as the developer never have access to the payment information, it is not collected and does not need to be disclosed.</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Credit Info</strong><br>Such as credit score</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Other Financial Info</strong><br>Such as salary, income, assets, debts, or any other financial information</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-location"></figure>
Location
</th>
</tr>
<tr>
<td><strong>Precise Location</strong><br>Information that describes the location of a user or device with the same or greater resolution as a latitude and longitude with three or more decimal places</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Coarse Location</strong><br>Information that describes the location of a user or device with lower resolution than a latitude and longitude with three or more decimal places, such as approximate location services</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-sensitive-info"></figure>
Sensitive Info
</th>
</tr>
<tr>
<td><strong>Sensitive Info</strong><br>Such as racial or ethnic data, sexual orientation, pregnancy or childbirth information, disability, religious or philosophical beliefs, trade union membership, political opinion, genetic information, or biometric data</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-contacts"></figure>
Contacts
</th>
</tr>
<tr>
<td><strong>Contacts</strong><br>Such as a list of contacts in the user’s phone, address book, or social graph</td>
<td><ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-user-content"></figure>
User Content
</th>
</tr>
<tr>
<td><strong>Emails or Text Messages</strong><br>Including subject line, sender, recipients, and contents of the email or message</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Photos or Videos</strong><br>The user’s photos or videos</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Audio Data</strong><br>The user’s voice or sound recordings</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Gameplay Conten</strong>t<br>Such as user-generated content in-game</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Customer Support</strong><br>Data generated by the user during a customer support request</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Other User Content</strong><br>Any other user-generated content</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-browsing-history"></figure>
Browsing History
</th>
</tr>
<tr>
<td><strong>Browsing History</strong><br>Information about content the user has viewed that is not part of the app, such as websites</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-search-history"></figure>
Search History
</th>
</tr>
<tr>
<td><strong>Search History</strong><br>Information about searches performed in the app</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-identifiers"></figure>
Identifiers
</th>
</tr>
<tr>
<td><strong>User ID</strong><br>Such as screen name, handle, account ID, assigned user ID, customer number, or other user- or account-level ID that can be used to identify a particular user or account</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Device ID</strong><br>Such as the device’s advertising identifier, or other device-level ID</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-purchase-history"></figure>
Purchases
</th>
</tr>
<tr>
<td><strong>Purchase History</strong><br>An account’s or individual’s purchases or purchase tendencies</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-usage-data"></figure>
Usage Data
</th>
</tr>
<tr>
<td><strong>Product Interaction</strong><br>Such as app launches, taps, clicks, scrolling information, music listening data, video views, saved place in a game, video, or song, or other information about how the user interacts with the app</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Advertising Data</strong><br>Such as information about the advertisements the user has seen</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Other Usage Data</strong><br>Any other data about user activity in the app</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-diagnostics"></figure>
Diagnostics
</th>
</tr>
<tr>
<td><strong>Crash Data</strong><br>Such as crash logs</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Performance Data</strong><br>Such as launch time, hang rate, or energy use</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<td><strong>Other Diagnostic Data</strong><br>Any other data collected for the purposes of measuring technical diagnostics related to the app</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
<tr>
<th colspan="2">
<figure class="category-icon icon-other-data"></figure>
Other Data
</th>
</tr>
<tr>
<td><strong>Other Data Types</strong><br>Any other data types not mentioned</td>
<td>										<ul>
<li>Does not collect data</li>
<ul></td>
</tr>
</tbody>
</table>


