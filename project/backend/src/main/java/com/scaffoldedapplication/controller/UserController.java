package com.scaffoldedapplication.controller;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * User API endpoints.
 */
@RestController
public class UserController {
  @GetMapping("/api/user/profile")
  public Map<String, String> profile() {
    return Map.of("username", "demo-user", "role", "USER");
  }
}
