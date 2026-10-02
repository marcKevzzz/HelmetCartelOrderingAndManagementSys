<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Auth.aspx.cs" Inherits="HelmetCartelOrderingAndManagementSys.Pages.Auth" ResponseEncoding="utf-8" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Authentication &mdash; Helmet Cartel</title>
    <link rel="icon" type="image/svg+xml" href="~/Content/images/favicon.svg" runat="server" />
    
    <!-- Design System CSS Tokens & Styles -->
    <link rel="stylesheet" href="~/Content/css/variables.css?v=4" runat="server" />
    <link rel="stylesheet" href="~/Content/css/reset.css?v=4" runat="server" />
    <link rel="stylesheet" href="~/Content/css/storefront/auth.css?v=6" runat="server" />
</head>
<body>
    <div class="auth-viewport">
        <!-- 1. Left Pane: Atmospheric Editorial Showcase -->
        <aside class="auth-showcase">
            <div class="auth-showcase__bg"></div>
            
            <div class="auth-showcase__content">
                <!-- Brand Header -->
                <div class="auth-showcase__top">
                    <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="auth-showcase__brand">
                        <span class="auth-showcase__brand-text">HELMET CARTEL</span>
                    </asp:HyperLink>
                </div>

                <!-- Editorial Centerpiece -->
                <div class="auth-showcase__mid">

                    <h1 class="auth-showcase__headline">
                        RIDE PROTECTED.<br />
                        RIDE UNAPOLOGETIC.
                    </h1>

                    <p class="auth-showcase__description">
                        Access real-time stock allocation for premier full-face racing helmets, modular touring helmets, and urban riders. Join thousands of verified riders across the Philippines.
                    </p>

                    <!-- Feature Pillars -->
                    <!-- <div class="auth-showcase__pillars">
                        <div class="auth-pillar">
                            <span class="auth-pillar__num">01 //</span>
                            <div>
                                <h3 class="auth-pillar__title">Real-Time Stock Locks</h3>
                                <p class="auth-pillar__desc">Instant inventory decrements prevent overselling across online and in-store channels.</p>
                            </div>
                        </div>

                        <div class="auth-pillar">
                            <span class="auth-pillar__num">02 //</span>
                            <div>
                                <h3 class="auth-pillar__title">Seamless HitPay Gateway</h3>
                                <p class="auth-pillar__desc">Encrypted local payments via GCash, Maya, QR Ph, and credit cards with instant webhook verification.</p>
                            </div>
                        </div>

                        <div class="auth-pillar">
                            <span class="auth-pillar__num">03 //</span>
                            <div>
                                <h3 class="auth-pillar__title">Track &amp; Street Heritage</h3>
                                <p class="auth-pillar__desc">100% authentic carbon fiber, fiberglass composite, and multi-density EPS impact technology.</p>
                            </div>
                        </div>
                    </div> -->
                </div>

                <!-- Console Footer -->
                 <footer class="auth-showcase__footer">
                    <span>&copy; 2026 HELMET CARTEL</span>
                    <span>ALL RIGHTS RESERVED</span>
                </footer>
            </div>
        </aside>

        <!-- 2. Right Pane: Interactive Auth Console -->
        <main class="auth-console">
            <!-- Form Canvas Area -->
            <div class="auth-form-canvas">
                <asp:HyperLink runat="server" NavigateUrl="~/Default.aspx" CssClass="auth-back-link">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="19" y1="12" x2="5" y2="12"></line>
                        <polyline points="12 19 5 12 12 5"></polyline>
                    </svg>
                    <span>Return to Storefront</span>
                </asp:HyperLink>
                <!-- Mode Switcher Tabs -->
                <div class="auth-mode-switch" role="tablist">
                    <button type="button" class="auth-mode-btn auth-mode-btn--active" id="tab-signin" role="tab" aria-selected="true">
                        Sign In
                    </button>
                    <button type="button" class="auth-mode-btn" id="tab-signup" role="tab" aria-selected="false">
                        Create Account
                    </button>
                </div>

                <!-- Notification Alert Banner -->
                <div class="auth-alert" id="auth-alert" role="alert">
                    <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="10"></circle>
                        <line x1="12" y1="8" x2="12" y2="12"></line>
                        <line x1="12" y1="16" x2="12.01" y2="16"></line>
                    </svg>
                    <span id="auth-alert-text"></span>
                </div>

                <!-- SIGN IN FORM -->
                <form id="form-signin" class="auth-form" method="post">
                    <div class="auth-header">
                        <h2 class="auth-header__title">Welcome Back</h2>
                        <p class="auth-header__subtitle">Sign in to access your order history and live dispatch status.</p>
                    </div>

                    <div class="auth-field-group">
                        <label for="signin-email" class="auth-field-label">Email Address</label>
                        <div class="auth-input-container">
                            <input type="email" id="signin-email" class="auth-input" placeholder="rider@helmetcartel.com" required autocomplete="username" />
                        </div>
                        <span class="auth-error-msg" id="err-signin-email"></span>
                    </div>

                    <div class="auth-field-group">
                        <label for="signin-password" class="auth-field-label">Password</label>
                        <div class="auth-input-container">
                            <input type="password" id="signin-password" class="auth-input" placeholder="Enter your password" required autocomplete="current-password" />
                            <button type="button" class="auth-toggle-pwd" aria-label="Toggle password visibility">
                                <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                                    <circle cx="12" cy="12" r="3"></circle>
                                </svg>
                            </button>
                        </div>
                        <span class="auth-error-msg" id="err-signin-password"></span>
                    </div>

                    <div class="auth-meta-row">
                        <label class="auth-checkbox-label">
                            <input type="checkbox" id="signin-remember" class="auth-checkbox" checked />
                            <span>Remember this device</span>
                        </label>
                        <a href="mailto:support@helmetcartel.com?subject=Password%20Reset" class="auth-link">Forgot password?</a>
                    </div>

                    <button type="submit" class="auth-submit-btn" id="btn-signin-submit">
                        <span class="auth-submit-text">Sign In to Cartel</span>
                        <span class="auth-spinner"></span>
                        <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <line x1="7" y1="17" x2="17" y2="7"></line>
                            <polyline points="7 7 17 7 17 17"></polyline>
                        </svg>
                    </button>

                </form>

                <!-- SIGN UP FORM -->
                <form id="form-signup" class="auth-form auth-form-hidden" method="post">
                    <div class="auth-header">
                        <h2 class="auth-header__title">Join the Cartel</h2>
                        <p class="auth-header__subtitle">Create your rider account for rapid checkout and real-time order tracking.</p>
                    </div>

                    <div class="auth-name-grid">
                        <div class="auth-field-group">
                            <label for="signup-firstname" class="auth-field-label">First Name</label>
                            <div class="auth-input-container"><input type="text" id="signup-firstname" class="auth-input" placeholder="Juan" required autocomplete="given-name" /></div>
                            <span class="auth-error-msg" id="err-signup-firstname"></span>
                        </div>
                        <div class="auth-field-group">
                            <label for="signup-lastname" class="auth-field-label">Last Name</label>
                            <div class="auth-input-container"><input type="text" id="signup-lastname" class="auth-input" placeholder="Dela Cruz" required autocomplete="family-name" /></div>
                            <span class="auth-error-msg" id="err-signup-lastname"></span>
                        </div>
                    </div>

                    <div class="auth-field-group">
                        <label for="signup-email" class="auth-field-label">Email Address</label>
                        <div class="auth-input-container">
                            <input type="email" id="signup-email" class="auth-input" placeholder="juan@rider.com" required autocomplete="email" />
                        </div>
                        <span class="auth-error-msg" id="err-signup-email"></span>
                    </div>

                    <div class="auth-field-group">
                        <label for="signup-phone" class="auth-field-label">Mobile Phone Number *</label>
                        <div class="auth-input-container">
                            <input type="tel" id="signup-phone" class="auth-input" placeholder="0917-123-4567" required autocomplete="tel" />
                        </div>
                        <span class="auth-error-msg" id="err-signup-phone"></span>
                    </div>

                    <div class="auth-field-group">
                        <label for="signup-password" class="auth-field-label">Password</label>
                        <div class="auth-input-container">
                            <input type="password" id="signup-password" class="auth-input" placeholder="At least 6 characters" required autocomplete="new-password" />
                            <button type="button" class="auth-toggle-pwd" aria-label="Toggle password visibility">
                                <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                                    <circle cx="12" cy="12" r="3"></circle>
                                </svg>
                            </button>
                        </div>
                        <span class="auth-error-msg" id="err-signup-password"></span>
                    </div>

                    <div class="auth-field-group">
                        <label for="signup-password-confirm" class="auth-field-label">Confirm Password</label>
                        <div class="auth-input-container">
                            <input type="password" id="signup-password-confirm" class="auth-input" placeholder="Repeat your password" required autocomplete="new-password" />
                        </div>
                        <span class="auth-error-msg" id="err-signup-password-confirm"></span>
                    </div>

                    <div class="auth-meta-row">
                        <label class="auth-checkbox-label">
                            <input type="checkbox" id="signup-agree" class="auth-checkbox" required checked />
                            <span>I agree to Helmet Cartel Terms &amp; Policies</span>
                        </label>
                    </div>

                    <button type="submit" class="auth-submit-btn" id="btn-signup-submit">
                        <span class="auth-submit-text">Create Account</span>
                        <span class="auth-spinner"></span>
                        <svg class="btn-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <line x1="7" y1="17" x2="17" y2="7"></line>
                            <polyline points="7 7 17 7 17 17"></polyline>
                        </svg>
                    </button>
                </form>
            </div>
        </main>
    </div>

    <!-- Modular Script -->
    <script type="module" src='<%= ResolveUrl("~/Scripts/storefront/auth.js?v=8") %>'></script>
</body>
</html>
