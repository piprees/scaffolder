package com.scaffoldedapplication.controller;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Admin API endpoints.
 */
@RestController
public class AdminController {
  @GetMapping("/api/admin/health")
  public Map<String, String> health() {
    return Map.of("status", "UP");
  }
}
