package com.scaffoldedapplication.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.DefaultOAuth2AuthorizationRequestResolver;
import org.springframework.security.oauth2.client.web.OAuth2AuthorizationRequestResolver;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.security.oauth2.client.web.OAuth2AuthorizationRequestRedirectFilter;

/**
 * Security configuration — GitHub OAuth2 login with public health endpoint.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http,
      org.springframework.security.oauth2.client.registration.ClientRegistrationRepository clientRegistrationRepository,
      OAuth2AuthorizationRequestResolver authorizationRequestResolver,
      AuthenticationSuccessHandler successHandler) throws Exception {
    http.authorizeHttpRequests(
            auth ->
                    auth.requestMatchers("/api/admin/health", "/api/greeting", "/api/user/profile", "/oauth2/**", "/login/oauth2/**")
                    .permitAll()
                    .anyRequest()
                    .authenticated())
        .oauth2Login(oauth2 -> oauth2
          .authorizationEndpoint(authorization -> authorization.authorizationRequestResolver(
            authorizationRequestResolver))
          .successHandler(successHandler))
        .csrf(
            csrf ->
                csrf.ignoringRequestMatchers("/api/admin/health", "/api/greeting", "/api/user/profile"));
    return http.build();
  }

  /**
   * Authorization request resolver that preserves a `return_to` request parameter into the
   * HTTP session so it can be used after successful authentication.
   */
  @Bean
  public OAuth2AuthorizationRequestResolver authorizationRequestResolver(
      ClientRegistrationRepository clientRegistrationRepository) {
    DefaultOAuth2AuthorizationRequestResolver defaultResolver =
        new DefaultOAuth2AuthorizationRequestResolver(
            clientRegistrationRepository, OAuth2AuthorizationRequestRedirectFilter.DEFAULT_AUTHORIZATION_REQUEST_BASE_URI);

    return new OAuth2AuthorizationRequestResolver() {
      @Override
      public org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest resolve(HttpServletRequest request) {
        var req = defaultResolver.resolve(request);
        if (req == null) {
          return null;
        }
        String returnTo = request.getParameter("return_to");
        if (returnTo != null && !returnTo.isEmpty()) {
          HttpSession session = request.getSession();
          session.setAttribute("RETURN_TO_AFTER_LOGIN", returnTo);
        }
        return req;
      }

      @Override
      public org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest resolve(HttpServletRequest request, String clientRegistrationId) {
        var req = defaultResolver.resolve(request, clientRegistrationId);
        if (req == null) {
          return null;
        }
        String returnTo = request.getParameter("return_to");
        if (returnTo != null && !returnTo.isEmpty()) {
          HttpSession session = request.getSession();
          session.setAttribute("RETURN_TO_AFTER_LOGIN", returnTo);
        }
        return req;
      }
    };
  }

  @Bean
  public AuthenticationSuccessHandler returnToSuccessHandler(
      @Value("${APP_HOSTNAME:}") String appHostname,
      @Value("${DROPLET_IP:}") String dropletIp) {

    String frontendBase;
    if (appHostname != null && !appHostname.isBlank()) {
      if (appHostname.startsWith("http://") || appHostname.startsWith("https://")) {
        frontendBase = appHostname;
      } else {
        // prefer https for hostnames; no port added
        frontendBase = "https://" + appHostname;
      }
    } else if (dropletIp != null && !dropletIp.isBlank()) {
      // droplet ip likely needs http scheme and may include port
      if (dropletIp.startsWith("http://") || dropletIp.startsWith("https://")) {
        frontendBase = dropletIp;
      } else {
        frontendBase = "http://" + dropletIp;
      }
    } else {
      frontendBase = "http://127.0.0.1:3000";
    }

    // strip trailing slash
    if (frontendBase.endsWith("/")) {
      frontendBase = frontendBase.substring(0, frontendBase.length() - 1);
    }

    final String finalFrontendBase = frontendBase;
    return (request, response, authentication) -> {
      HttpSession session = request.getSession(false);
      String target = finalFrontendBase + "/"; // default to frontend root
      if (session != null) {
        Object o = session.getAttribute("RETURN_TO_AFTER_LOGIN");
        if (o instanceof String) {
          String returnTo = (String) o;
          if (returnTo.startsWith("/")) {
            // Redirect to frontend host with the relative path
            target = finalFrontendBase + returnTo;
          } else if (returnTo.startsWith("http://") || returnTo.startsWith("https://")) {
            // Allow absolute return URLs only if they start with frontendBase to avoid open redirect
            if (returnTo.startsWith(finalFrontendBase)) {
              target = returnTo;
            }
          }
        }
        // remove attribute after use
        session.removeAttribute("RETURN_TO_AFTER_LOGIN");
      }
      response.sendRedirect(target);
    };
  }
}
