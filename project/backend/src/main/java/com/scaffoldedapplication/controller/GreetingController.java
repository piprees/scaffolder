package com.scaffoldedapplication.controller;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Greeting API endpoints.
 */
@RestController
public class GreetingController {
  @GetMapping("/api/greeting")
  public Map<String, Object> greeting() {
    return Map.of("id", 1, "message", "Hello, World!");
  }
}
